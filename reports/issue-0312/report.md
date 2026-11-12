# #312 Website: untrusted reverse proxy no longer silent; proxy ranges; clear start errors

| | |
|---|---|
| Branch | `fix/website-proxy-config` from `incremental-test` @ `470effb` |
| Environment | Student PC, Windows 11 Home, .NET 10, DLLs `ADAE03D2…` / `75F43A5B…` |
| Command | `dotnet test website\backend\tests\Xpact.Api.Tests` |

## Problem and cause
Behind a proxy that is not trusted, `X-Forwarded-For` is ignored (correct, a visitor must not choose their address), but **silently**: every visitor then looks like the proxy and the rate limit and the per-visitor worker share (#297) apply to all of them together. No CIDR ranges; a mistyped address gave a bare `FormatException`. ✅ Confirmed by the code.

## Change
- `Program.cs`: after `UseForwardedHeaders`, a header left unprocessed from a non-loopback address logs a warning **once per address** (at most 100 addresses kept), naming `Xpact:KnownProxies` / `Xpact:KnownNetworks`.
- `XpactOptions.KnownNetworks` (CIDR) → `ForwardedHeadersOptions.KnownIPNetworks`.
- Both settings validated at start, with a message naming the bad entry.
- `docker.md`: which setup needs which setting; `api.md`, `security.md` updated.

The real proxy address belongs to the deployment (supervisor, #210).

## Verification ([log](test-website.txt))
| Check | Result |
|---|---|
| Untrusted proxy: two visitors share one limit, warning names the proxy | ✅ |
| `KnownProxies` = proxy: separate limits, no warning | ✅ |
| `KnownNetworks` = proxy's /24: separate limits, no warning | ✅ |
| Mistyped address / network: start stops with "is not an IP address" / "is not a network" | ✅ |
| Same test with the warning switched off (temporary) | ❌ fails as it should ("expected a warning naming the untrusted proxy") |
| All backend tests | ✅ 42/42 |
