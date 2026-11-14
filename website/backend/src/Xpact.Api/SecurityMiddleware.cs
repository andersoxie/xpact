using System.Collections.Concurrent;
using System.Net;
using Microsoft.AspNetCore.HttpOverrides;

namespace Xpact.Api;

/// <summary>Proxy trust, the untrusted-proxy warning and the security headers.</summary>
internal static class SecurityMiddleware
{
    /// <summary>
    /// Behind IIS or nginx the visitor's address arrives in X-Forwarded-For. Only a proxy on this
    /// machine, one listed in KnownProxies or one inside KnownNetworks is believed, so a visitor cannot
    /// pick their own address. A wrong entry stops the start with a message naming it.
    /// </summary>
    public static void ConfigureForwardedHeaders(ForwardedHeadersOptions o, XpactOptions xpact)
    {
        o.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
        foreach (string proxy in xpact.KnownProxies)
        {
            if (!IPAddress.TryParse(proxy, out IPAddress? address))
                throw new InvalidOperationException($"Xpact:KnownProxies: '{proxy}' is not an IP address.");
            o.KnownProxies.Add(address);
        }
        foreach (string network in xpact.KnownNetworks)
        {
            if (!System.Net.IPNetwork.TryParse(network, out System.Net.IPNetwork range))
                throw new InvalidOperationException($"Xpact:KnownNetworks: '{network}' is not a network such as 10.0.0.0/24.");
            o.KnownIPNetworks.Add(range);
        }
    }

    /// <summary>
    /// A proxy that is not trusted is silently ignored: every visitor then looks like the proxy, and the
    /// rate limit and the per-visitor worker cap apply to all of them together. Say so in the log, once
    /// per proxy address, naming the setting to change.
    /// </summary>
    public static IApplicationBuilder UseUntrustedProxyWarning(this IApplicationBuilder app)
    {
        var warned = new ConcurrentDictionary<string, bool>();
        return app.Use(async (context, next) =>
        {
            if (context.Request.Headers.ContainsKey("X-Forwarded-For")
                && context.Connection.RemoteIpAddress is { } proxy && !IPAddress.IsLoopback(proxy)
                && warned.Count < 100 && warned.TryAdd(proxy.ToString(), true))
            {
                context.RequestServices.GetRequiredService<ILogger<Program>>().LogWarning(
                    "X-Forwarded-For from {Proxy} was ignored: that address is not trusted. If it is your reverse proxy, " +
                    "add it to Xpact:KnownProxies (or its range to Xpact:KnownNetworks); until then all visitors behind it " +
                    "share one rate limit and one worker share.", proxy);
            }
            await next();
        });
    }

    public static IApplicationBuilder UseSecurityHeaders(this IApplicationBuilder app) =>
        app.Use(async (context, next) =>
        {
            var headers = context.Response.Headers;
            headers.XContentTypeOptions = "nosniff";
            headers["Referrer-Policy"] = "no-referrer";
            headers.XFrameOptions = "DENY";
            // React sets style props through the DOM (element.style), which CSP allows, so inline styles need no
            // 'unsafe-inline'. base-uri, form-action and object-src do not fall back to default-src: set them too.
            headers.ContentSecurityPolicy =
                "default-src 'self'; img-src 'self' data:; style-src 'self'; connect-src 'self'; frame-ancestors 'none'; " +
                "base-uri 'self'; form-action 'self'; object-src 'none'";
            headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=(), payment=(), usb=()";
            headers["Cross-Origin-Opener-Policy"] = "same-origin";
            headers["Cross-Origin-Resource-Policy"] = "same-origin";
            await next();
        });
}
