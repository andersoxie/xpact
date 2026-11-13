using System.Diagnostics;
using System.Net.Sockets;
using System.Text;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Xpact.Api.Tests;

/// <summary>#358: an upload that trickles in is cut off by RequestTimeoutSeconds instead of holding the server.</summary>
public sealed class SlowUploadTests(WebApplicationFactory<Program> factory) : IClassFixture<WebApplicationFactory<Program>>
{
    [Fact]
    public async Task A_trickling_upload_is_stopped_by_the_request_timeout()
    {
        // Real Kestrel on a free port: the in-memory test host hands the app the whole body at once,
        // and HttpClient only reads the answer after sending everything, so talk raw TCP like an attacker.
        using var server = factory.WithWebHostBuilder(b => b.UseSetting("Xpact:RequestTimeoutSeconds", "2"));
        server.UseKestrel(0);
        server.StartServer();
        Uri address = server.ClientOptions.BaseAddress;

        using var tcp = new TcpClient();
        await tcp.ConnectAsync(address.Host, address.Port);
        var stream = tcp.GetStream();
        await stream.WriteAsync(Encoding.ASCII.GetBytes(
            "POST /api/validate HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/xml\r\nContent-Length: 20000000\r\n\r\n<root>"));

        // 8 KB per second: above Kestrel's minimum data rate, so only the request timeout can stop it.
        var clock = Stopwatch.StartNew();
        var answer = new byte[200];
        Task<int> read = stream.ReadAsync(answer).AsTask();
        while (!read.IsCompleted && clock.Elapsed < TimeSpan.FromSeconds(15))
        {
            try { await stream.WriteAsync(new byte[8192]); } catch (IOException) { break; }
            await Task.WhenAny(read, Task.Delay(1000));
        }
        int n = read.IsCompleted ? await read : 0;
        clock.Stop();

        string head = Encoding.ASCII.GetString(answer, 0, n);
        Assert.True(clock.Elapsed < TimeSpan.FromSeconds(8), $"no answer after {clock.Elapsed.TotalSeconds:F1} s");
        Assert.StartsWith("HTTP/1.1 504", head);
    }
}
