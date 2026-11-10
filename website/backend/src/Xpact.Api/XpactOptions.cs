namespace Xpact.Api;

/// <summary>Settings from the "Xpact" section of appsettings.json. Relative paths start at the API's own folder.</summary>
public sealed class XpactOptions
{
    public const string Section = "Xpact";

    /// <summary>The worker executable; it is copied next to the API at build time.</summary>
    public string WorkerPath { get; set; } = "Xpact.Worker.exe";

    /// <summary>Build name → DLL path. The first entry is the default build.</summary>
    public Dictionary<string, string> Builds { get; set; } = new()
    {
        ["production"] = "native/xpact.dll",
        ["assertions"] = "native/xpact_assertions.dll",
    };

    /// <summary>Largest document accepted, in bytes.</summary>
    public int MaxDocumentBytes { get; set; } = 1024 * 1024;

    /// <summary>A worker that runs longer is killed and the result is "timeout".</summary>
    public int TimeoutSeconds { get; set; } = 10;

    /// <summary>Memory cap per worker process (Windows Job Object).</summary>
    public int WorkerMemoryMb { get; set; } = 512;

    /// <summary>Workers running at once; further requests wait for a free slot.</summary>
    public int MaxConcurrentWorkers { get; set; } = 4;

    /// <summary>Requests per client IP per minute.</summary>
    public int RequestsPerMinute { get; set; } = 30;

    /// <summary>Events kept in the result sample.</summary>
    public int MaxEvents { get; set; } = 200;

    /// <summary>Smallest chunk size the API allows (1 = byte by byte).</summary>
    public int MinChunkSize { get; set; } = 1;

    /// <summary>Folder with the conformance and benchmark JSON files (website/data).</summary>
    public string DataDirectory { get; set; } = "data";

    /// <summary>
    /// Reverse proxies whose X-Forwarded-For / X-Forwarded-Proto headers are trusted, besides one on
    /// this machine (always trusted). Without this, the rate limit would count every visitor as the proxy.
    /// </summary>
    public string[] KnownProxies { get; set; } = [];

    /// <summary>Resolve a configured path against the API folder.</summary>
    public static string Resolve(string path) =>
        Path.IsPathRooted(path) ? path : Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, path));
}
