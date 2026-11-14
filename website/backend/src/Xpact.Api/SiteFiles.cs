namespace Xpact.Api;

/// <summary>Browser caching for the React site.</summary>
internal static class SiteFiles
{
    /// <summary>
    /// Files under /assets/ have a content hash in their name (Vite), so a new build gets new names:
    /// browsers may keep them for a year. Everything else (index.html, favicon, robots.txt) is checked
    /// on every visit, so a new release shows up at once.
    /// </summary>
    public static readonly StaticFileOptions Options = new()
    {
        OnPrepareResponse = context =>
        {
            context.Context.Response.Headers.CacheControl =
                context.Context.Request.Path.StartsWithSegments("/assets")
                    ? "public, max-age=31536000, immutable"
                    : "no-cache";
        },
    };
}
