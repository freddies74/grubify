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

            // Sanitize path to prevent log forging attacks
            var sanitizedPath = SanitizePath(path);

            // Log at appropriate level based on latency
            if (path.Contains("/category/", StringComparison.OrdinalIgnoreCase))
            {
                if (elapsedMs > 1000)
                {
                    _logger.LogWarning(
                        "Slow category query - Method: {Method}, Path: {Path}, Status: {StatusCode}, Latency: {LatencyMs}ms",
                        method, sanitizedPath, statusCode, elapsedMs);
                }
                else if (elapsedMs > 100)
                {
                    _logger.LogInformation(
                        "Category query - Method: {Method}, Path: {Path}, Status: {StatusCode}, Latency: {LatencyMs}ms",
                        method, sanitizedPath, statusCode, elapsedMs);
                }
                else
                {
                    _logger.LogDebug(
                        "Fast category query - Method: {Method}, Path: {Path}, Status: {StatusCode}, Latency: {LatencyMs}ms",
                        method, sanitizedPath, statusCode, elapsedMs);
                }
            }
            else
            {
                _logger.LogDebug(
                    "Request - Method: {Method}, Path: {Path}, Status: {StatusCode}, Latency: {LatencyMs}ms",
                    method, sanitizedPath, statusCode, elapsedMs);
            }
        }

        private static string SanitizePath(string path)
        {
            // Replace control characters and newlines to prevent log injection
            return path.Replace("\r", "").Replace("\n", "").Replace("\t", " ");
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
