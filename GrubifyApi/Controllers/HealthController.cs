using Microsoft.AspNetCore.Mvc;

namespace GrubifyApi.Controllers
{
    [ApiController]
    public class HealthController : ControllerBase
    {
        private readonly ILogger<HealthController> _logger;
        private readonly IConfiguration _configuration;

        public HealthController(ILogger<HealthController> logger, IConfiguration configuration)
        {
            _logger = logger;
            _configuration = configuration;
        }

        [HttpGet("/livez")]
        public IActionResult GetLiveness()
        {
            return Ok(new { status = "alive" });
        }

        [HttpGet("/api/health")]
        public IActionResult GetHealth()
        {
            if (_configuration.GetValue<bool>("IncidentSimulation:SimulateDbConnectTimeout"))
            {
                _logger.LogError("Health check degraded: DB connect timeout.");
                return StatusCode(StatusCodes.Status503ServiceUnavailable, new
                {
                    status = "degraded",
                    dependency = "database",
                    failureType = "connect-timeout"
                });
            }

            return Ok(new
            {
                status = "healthy",
                dependencies = new
                {
                    database = "healthy"
                }
            });
        }
    }
}
