namespace GrubifyApi.Services
{
    /// <summary>
    /// Service to track application lifetime metrics like startup time.
    /// Initialized in Program.cs at application startup.
    /// </summary>
    public interface IApplicationLifetimeService
    {
        TimeSpan Uptime { get; }
        DateTime StartTime { get; }
    }

    public class ApplicationLifetimeService : IApplicationLifetimeService
    {
        private readonly DateTime _startTime;

        public ApplicationLifetimeService()
        {
            _startTime = DateTime.UtcNow;
        }

        public DateTime StartTime => _startTime;

        public TimeSpan Uptime => DateTime.UtcNow - _startTime;
    }
}
