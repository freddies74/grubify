using System.Text.RegularExpressions;

namespace GrubifyApi.Middleware
{
    /// <summary>
    /// Middleware for logging request latency for telemetry.
    /// Captures request/response timing for endpoints to monitor performance.
    /// </summary>
    public class LatencyLoggingMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly ILogger<LatencyLoggingMiddleware> _logger;

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

            var method = context.Request.Method;
            var statusCode = context.Response.StatusCode;
            var elapsedMs = stopwatch.ElapsedMilliseconds;
            
            // Determine if this is a category query based on safe pattern matching
            var path = context.Request.Path.Value ?? string.Empty;
            var isCategoryQuery = path.Contains("/category/", StringComparison.OrdinalIgnoreCase);

            // Log latency - without logging the actual path to prevent log injection
            // Only log method, status, and latency which are controlled by the framework
            if (isCategoryQuery)
            {
                if (elapsedMs > 1000)
                {
                    _logger.LogWarning(
                        "Slow category query - Method: {Method}, Status: {StatusCode}, Latency: {LatencyMs}ms",
                        method, statusCode, elapsedMs);
                }
                else if (elapsedMs > 100)
                {
                    _logger.LogInformation(
                        "Category query - Method: {Method}, Status: {StatusCode}, Latency: {LatencyMs}ms",
                        method, statusCode, elapsedMs);
                }
                else
                {
                    _logger.LogDebug(
                        "Fast category query - Method: {Method}, Status: {StatusCode}, Latency: {LatencyMs}ms",
                        method, statusCode, elapsedMs);
                }
            }
            else
            {
                _logger.LogDebug(
                    "Request - Method: {Method}, Status: {StatusCode}, Latency: {LatencyMs}ms",
                    method, statusCode, elapsedMs);
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
