using System.Text.RegularExpressions;

namespace GrubifyApi.Middleware
{
    /// <summary>
    /// Middleware for logging category query latency for telemetry.
    /// Captures request/response timing for category endpoints to monitor cold-start performance.
    /// </summary>
    public class LatencyLoggingMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly ILogger<LatencyLoggingMiddleware> _logger;
        // Regex pattern to allow only safe characters in log output (alphanumeric, spaces, common URL chars)
        private static readonly Regex SafePathPattern = new(@"^[a-zA-Z0-9\-._~:/?#\[\]@!$&'()*+,;=]+$", RegexOptions.Compiled);

        public LatencyLoggingMiddleware(RequestDelegate next, ILogger<LatencyLoggingMiddleware> logger)
        {
            _next = next;
            _logger = logger;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            var stopwatch = System.Diagnostics.Stopwatch.StartNew();
            
            // Call the next middleware
            await _next(context);
            
            stopwatch.Stop();

            // Log latency for category queries (and other endpoints)
            var path = context.Request.Path.Value ?? string.Empty;
            var method = context.Request.Method;
            var statusCode = context.Response.StatusCode;
            var elapsedMs = stopwatch.ElapsedMilliseconds;

            // Validate path is safe for logging
            var isPathSafe = SafePathPattern.IsMatch(path);
            var displayPath = isPathSafe ? path : "[UNSAFE_PATH]";

            // Log at appropriate level based on latency
            if (path.Contains("/category/", StringComparison.OrdinalIgnoreCase))
            {
                if (elapsedMs > 1000)
                {
                    _logger.LogWarning(
                        "Slow category query - Method: {Method}, Path: {Path}, Status: {StatusCode}, Latency: {LatencyMs}ms",
                        method, displayPath, statusCode, elapsedMs);
                }
                else if (elapsedMs > 100)
                {
                    _logger.LogInformation(
                        "Category query - Method: {Method}, Path: {Path}, Status: {StatusCode}, Latency: {LatencyMs}ms",
                        method, displayPath, statusCode, elapsedMs);
                }
                else
                {
                    _logger.LogDebug(
                        "Fast category query - Method: {Method}, Path: {Path}, Status: {StatusCode}, Latency: {LatencyMs}ms",
                        method, displayPath, statusCode, elapsedMs);
                }
            }
            else
            {
                _logger.LogDebug(
                    "Request - Method: {Method}, Path: {Path}, Status: {StatusCode}, Latency: {LatencyMs}ms",
                    method, displayPath, statusCode, elapsedMs);
            }
        }
    }

    /// <summary>
    /// Extension method to add latency logging middleware to the pipeline.
    /// </summary>
    public static class LatencyLoggingMiddlewareExtensions
    {
        public static IApplicationBuilder UseLatencyLogging(this IApplicationBuilder builder)
        {
            return builder.UseMiddleware<LatencyLoggingMiddleware>();
        }
    }
}
