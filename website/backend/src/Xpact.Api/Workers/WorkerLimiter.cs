using System.Diagnostics;

namespace Xpact.Api.Workers;

/// <summary>
/// Puts a started worker process under its limits. The returned handle must stay alive until the
/// worker has finished: disposing it ends the limits (and, for the Job Object, kills the worker).
/// Throws if the limits cannot be set; the caller must then stop the worker (fail closed).
/// </summary>
public interface IWorkerLimiter
{
    IDisposable Limit(Process process, long memoryLimitBytes);
}

/// <summary>The real limiter: a Windows Job Object with a memory cap that kills the worker when closed.</summary>
public sealed class JobObjectWorkerLimiter : IWorkerLimiter
{
    public IDisposable Limit(Process process, long memoryLimitBytes)
    {
        var job = new JobObject(memoryLimitBytes);
        try
        {
            job.Assign(process);
            return job;
        }
        catch
        {
            job.Dispose();
            throw;
        }
    }
}
