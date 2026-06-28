using Microsoft.AspNetCore.Mvc;
using GrubifyApi.Services;

namespace GrubifyApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class HealthController : ControllerBase
    {
        private readonly IDatabaseHealthService _databaseHealth;
        private readonly ILogger<HealthController> _logger;

        public HealthController(IDatabaseHealthService databaseHealth, ILogger<HealthController> logger)
        {
            _databaseHealth = databaseHealth;
            _logger = logger;
        }

        /// <summary>
        /// Returns the health status of the API and its dependencies.
        /// Returns 200 when healthy, 503 when any critical dependency is unavailable.
        /// </summary>
        [HttpGet]
        public async Task<IActionResult> GetHealth(CancellationToken cancellationToken)
        {
            var dbResult = await _databaseHealth.CheckAsync(cancellationToken);

            var overallHealthy = dbResult.Availability is DatabaseAvailability.Healthy
                or DatabaseAvailability.NotConfigured;

            var response = new
            {
                status = ToStatusString(overallHealthy),
                timestamp = DateTimeOffset.UtcNow,
                checks = new
                {
                    database = new
                    {
                        status = ToStatusString(dbResult.Availability is DatabaseAvailability.Healthy
                            or DatabaseAvailability.NotConfigured),
                        description = dbResult.Description,
                        errorCode = dbResult.ErrorCode
                    }
                }
            };

            if (!overallHealthy)
            {
                _logger.LogWarning(
                    "Health check returning 503: database dependency is {Availability} — {Description}",
                    dbResult.Availability, dbResult.Description);

                return StatusCode(StatusCodes.Status503ServiceUnavailable, response);
            }

            return Ok(response);
        }

        private static string ToStatusString(bool healthy) => healthy ? "healthy" : "unhealthy";
    }
}
