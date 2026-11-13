using System.Collections.Concurrent;
using System.Net;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Xpact.Api.Tests;

/// <summary>#359: an uploaded document is never written to a temp file (security.md: nothing on disk).</summary>
public sealed class UploadInMemoryTests(WebApplicationFactory<Program> factory) : IClassFixture<WebApplicationFactory<Program>>
{
    [Fact]
    public async Task A_large_uploaded_file_does_not_touch_the_temp_folder()
    {
        string temp = Environment.GetEnvironmentVariable("ASPNETCORE_TEMP") is { Length: > 0 } t ? t : Path.GetTempPath();
        var created = new ConcurrentBag<string>();
        using var watcher = new FileSystemWatcher(temp, "ASPNETCORE_*") { EnableRaisingEvents = true };
        watcher.Created += (_, e) => created.Add(e.Name ?? "");

        // 2 MB: far above ASP.NET's default 64 KB threshold for spooling form files to disk.
        byte[] doc = System.Text.Encoding.ASCII.GetBytes("<r>" + new string('x', 2 * 1024 * 1024) + "</r>");
        using var form = new MultipartFormDataContent { { new ByteArrayContent(doc), "file", "big.xml" } };
        var response = await factory.CreateClient().PostAsync("/api/validate", form);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        await Task.Delay(200); // let the watcher report anything late
        Assert.Empty(created);
    }
}
