using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;

namespace Xpact.Api;

/// <summary>
/// #455: which content root the API starts with. The published layout (scripts/publish.ps1) keeps wwwroot and
/// appsettings.json next to Xpact.Api.exe, but the host's default content root is the current folder, so the exe
/// started from elsewhere (e.g. the repository root) answered /api/health and gave 404 for the site.
/// The exe's folder is only a fallback: an operator's explicit root always wins.
/// </summary>
public static class ContentRoot
{
    /// <summary>
    /// The folder to pass as ContentRootPath, or null to keep the host's own choice. Null when the operator set a
    /// root (--contentRoot, DOTNET_CONTENTROOT or ASPNETCORE_CONTENTROOT, read the same way the host reads them)
    /// or when <paramref name="exeDir"/> holds no built site (dotnet run, tests).
    /// </summary>
    public static string? Fallback(string[] args, string exeDir, IDictionary<string, string?>? environment = null)
    {
        if (IsExplicit(args, environment)) return null;
        return File.Exists(Path.Combine(exeDir, "wwwroot", "index.html")) ? exeDir : null;
    }

    /// <summary>True when the command line or the environment sets the content root.</summary>
    public static bool IsExplicit(string[] args, IDictionary<string, string?>? environment = null)
    {
        var config = new ConfigurationBuilder();
        if (environment is null)
        {
            config.AddEnvironmentVariables("DOTNET_").AddEnvironmentVariables("ASPNETCORE_");
        }
        else
        {
            // Tests pass their own variables; same prefixes and order as the host.
            config.AddInMemoryCollection(Strip(environment, "DOTNET_")).AddInMemoryCollection(Strip(environment, "ASPNETCORE_"));
        }
        config.AddCommandLine(args);
        return !string.IsNullOrEmpty(config.Build()[HostDefaults.ContentRootKey]);
    }

    private static IEnumerable<KeyValuePair<string, string?>> Strip(IDictionary<string, string?> env, string prefix) =>
        env.Where(e => e.Key.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
           .Select(e => new KeyValuePair<string, string?>(e.Key[prefix.Length..], e.Value));
}
