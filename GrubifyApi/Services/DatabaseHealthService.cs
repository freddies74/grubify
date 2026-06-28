using Npgsql;
using System.Net.Sockets;

namespace GrubifyApi.Services
{
    public enum DatabaseAvailability
    {
        Healthy,
        Unavailable,
        NotConfigured,
        Unknown
    }

    public record DatabaseHealthResult(
        DatabaseAvailability Availability,
        string Description,
        string? ErrorCode = null,
        Exception? Exception = null);

    public interface IDatabaseHealthService
    {
        Task<DatabaseHealthResult> CheckAsync(CancellationToken cancellationToken = default);
    }

    public class DatabaseHealthService : IDatabaseHealthService
    {
        private readonly IConfiguration _configuration;
        private readonly ILogger<DatabaseHealthService> _logger;
        private readonly TimeSpan _connectionTimeout;

        // Default timeout — keeps health checks fast during database outages
        private const int DefaultTimeoutSeconds = 5;

        public DatabaseHealthService(IConfiguration configuration, ILogger<DatabaseHealthService> logger)
        {
            _configuration = configuration;
            _logger = logger;

            // Note: timeout is read at construction time. Changes to HealthCheck:TimeoutSeconds
            // in configuration require an application restart to take effect.
            var configuredTimeout = _configuration.GetValue<int?>("HealthCheck:TimeoutSeconds");
            _connectionTimeout = TimeSpan.FromSeconds(configuredTimeout ?? DefaultTimeoutSeconds);
        }

        public async Task<DatabaseHealthResult> CheckAsync(CancellationToken cancellationToken = default)
        {
            var connectionString = _configuration.GetConnectionString("DefaultConnection");

            if (string.IsNullOrWhiteSpace(connectionString))
            {
                _logger.LogWarning("Database health check skipped: DefaultConnection is not configured.");
                return new DatabaseHealthResult(
                    DatabaseAvailability.NotConfigured,
                    "No database connection string configured.");
            }

            // Validate the connection string format before attempting to connect.
            // This catches malformed strings early and gives a clear diagnostic instead
            // of a cryptic driver-level error.
            try
            {
                _ = new NpgsqlConnectionStringBuilder(connectionString);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Database health check aborted: connection string is malformed.");
                return new DatabaseHealthResult(
                    DatabaseAvailability.Unknown,
                    "Database connection string is malformed.",
                    "INVALID_CONNECTION_STRING",
                    ex);
            }

            using var cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            cts.CancelAfter(_connectionTimeout);

            try
            {
                await using var connection = new NpgsqlConnection(connectionString);
                await connection.OpenAsync(cts.Token);

                await using var command = connection.CreateCommand();
                command.CommandText = "SELECT 1";
                await command.ExecuteScalarAsync(cts.Token);

                _logger.LogDebug("Database health check passed.");
                return new DatabaseHealthResult(DatabaseAvailability.Healthy, "Database is reachable and responding.");
            }
            catch (OperationCanceledException) when (cts.IsCancellationRequested && !cancellationToken.IsCancellationRequested)
            {
                _logger.LogError("Database health check timed out after {Timeout}s.", _connectionTimeout.TotalSeconds);
                return new DatabaseHealthResult(
                    DatabaseAvailability.Unavailable,
                    $"Database connection timed out after {_connectionTimeout.TotalSeconds}s.",
                    "TIMEOUT");
            }
            catch (NpgsqlException ex) when (IsConnectionRefused(ex))
            {
                _logger.LogError(ex,
                    "Database health check failed: connection refused (ECONNREFUSED). " +
                    "The PostgreSQL server may be stopped or unreachable.");
                return new DatabaseHealthResult(
                    DatabaseAvailability.Unavailable,
                    "PostgreSQL connection refused — the server may be stopped or unreachable (ECONNREFUSED).",
                    "ECONNREFUSED",
                    ex);
            }
            catch (NpgsqlException ex)
            {
                _logger.LogError(ex,
                    "Database health check failed with PostgreSQL error {SqlState}: {Message}",
                    ex.SqlState, ex.Message);
                return new DatabaseHealthResult(
                    DatabaseAvailability.Unavailable,
                    $"PostgreSQL error: {ex.Message}",
                    ex.SqlState ?? "POSTGRES_ERROR",
                    ex);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Database health check failed with unexpected error: {Message}", ex.Message);
                return new DatabaseHealthResult(
                    DatabaseAvailability.Unknown,
                    $"Unexpected error during database connectivity check: {ex.Message}",
                    "UNKNOWN",
                    ex);
            }
        }

        private static bool IsConnectionRefused(NpgsqlException ex)
        {
            // Prefer the strongly-typed SocketException check.
            // The string-based fallback is a defensive measure for cases where Npgsql wraps
            // the error differently across versions or platforms.
            if (ex.InnerException is SocketException socketEx)
            {
                return socketEx.SocketErrorCode == SocketError.ConnectionRefused;
            }

            return ex.Message.Contains("Connection refused", StringComparison.OrdinalIgnoreCase)
                || ex.Message.Contains("ECONNREFUSED", StringComparison.OrdinalIgnoreCase);
        }
    }
}
