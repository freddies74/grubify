using Microsoft.AspNetCore.Mvc;
using GrubifyApi.Services;

namespace GrubifyApi.Controllers
{
    [ApiController]
    [Route("health")]
    public class HealthController : ControllerBase
    {
        private readonly IApplicationLifetimeService _lifetimeService;

        public HealthController(IApplicationLifetimeService lifetimeService)
        {
            _lifetimeService = lifetimeService;
        }

        /// <summary>
        /// Liveness probe - indicates if the pod is running and should stay running.
        /// Returns 200 OK if the service is alive.
        /// </summary>
        [HttpGet("live")]
        public ActionResult<HealthResponse> Live()
        {
            return Ok(new HealthResponse
            {
                Status = "alive",
                Timestamp = DateTime.UtcNow,
                Uptime = _lifetimeService.Uptime
            });
        }

        /// <summary>
        /// Readiness probe - indicates if the pod is ready to serve traffic.
        /// Returns 200 OK if all dependencies are available and the service is ready.
        /// Note: Currently checks are placeholder. In production, this should verify database connectivity,
        /// cache availability, and other critical dependencies.
        /// </summary>
        [HttpGet("ready")]
        public ActionResult<HealthResponse> Ready()
        {
            // TODO: Implement actual dependency checks:
            // - Database connectivity verification
            // - Cache service availability
            // - External API endpoint health
            // For now, we just verify that the service is running and responding.
            var response = new HealthResponse
            {
                Status = "ready",
                Timestamp = DateTime.UtcNow,
                Uptime = _lifetimeService.Uptime
                // Dependencies field omitted until actual checks are implemented to prevent false positives
            };
            return Ok(response);
        }
    }

    public class HealthResponse
    {
        public string Status { get; set; } = string.Empty;
        public DateTime Timestamp { get; set; }
        public TimeSpan Uptime { get; set; }
        public Dictionary<string, string>? Dependencies { get; set; }
    }
}
