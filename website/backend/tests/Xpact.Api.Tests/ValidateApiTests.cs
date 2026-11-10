using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using Microsoft.AspNetCore.Mvc.Testing;
using Xpact.Contracts;

namespace Xpact.Api.Tests;

/// <summary>
/// End-to-end tests: the API runs in memory, but every document really goes through
/// Xpact.Worker.exe and native/xpact.dll (copied into the test output folder).
/// Run website/scripts/build-dll.ps1 first, so the DLLs exist.
/// </summary>
public sealed class ValidateApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public ValidateApiTests(WebApplicationFactory<Program> factory) => _factory = factory;

    private HttpClient Client(params (string Key, string Value)[] settings) =>
        _factory.WithWebHostBuilder(b =>
        {
            foreach (var (key, value) in settings) b.UseSetting(key, value);
        }).CreateClient();

    private static async Task<ValidationResult> PostJson(HttpClient client, object body)
    {
        var response = await client.PostAsJsonAsync("/api/validate", body);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<ValidationResult>())!;
    }

    [Fact]
    public async Task Health_and_info_report_both_builds()
    {
        var client = Client();
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/health")).StatusCode);
        string info = await client.GetStringAsync("/api/info");
        Assert.Contains("\"name\":\"production\",\"available\":true", info);
        Assert.Contains("\"name\":\"assertions\",\"available\":true", info);
    }

    [Theory]
    [InlineData("production")]
    [InlineData("assertions")]
    public async Task Well_formed_document_is_accepted_with_events(string build)
    {
        var result = await PostJson(Client(), new
        {
            xml = "<?xml version=\"1.0\"?>\n<!-- c --><root a=\"1\"><child>hello</child><?pi d?></root>",
            build,
        });

        Assert.Equal(Verdicts.Accepted, result.Verdict);
        Assert.True(result.WellFormed);
        Assert.Equal(build, result.Build);
        Assert.Null(result.Error);
        Assert.Equal(2, result.Events.StartElements);
        Assert.Equal(2, result.Events.EndElements);
        Assert.Equal(1, result.Events.Comments);
        Assert.Equal(1, result.Events.ProcessingInstructions);
        Assert.Contains(result.Events.Sample, e => e.Kind == "start" && e.Name == "root" && e.Value == "a=\"1\"");
        Assert.Contains(result.Events.Sample, e => e.Kind == "text" && e.Value == "hello");
    }

    [Fact]
    public async Task Mismatched_tag_is_rejected_with_code_and_position()
    {
        var result = await PostJson(Client(), new { xml = "<root>\n  <child>\n</root>" });

        Assert.Equal(Verdicts.Rejected, result.Verdict);
        Assert.NotNull(result.Error);
        Assert.Equal(7, result.Error!.Code);          // XML_ERROR_TAG_MISMATCH
        Assert.Equal("mismatched tag", result.Error.Message);
        Assert.Equal(3u, result.Error.Line);
    }

    [Theory]
    [InlineData("", 3)]                              // XML_ERROR_NO_ELEMENTS
    [InlineData("<root>", 3)]                         // unclosed root at the end: Expat also says "no element found"
    [InlineData("<root/>junk", 9)]                    // XML_ERROR_JUNK_AFTER_DOC_ELEMENT (#124)
    [InlineData("<a b='1' b='2'/>", 8)]               // XML_ERROR_DUPLICATE_ATTRIBUTE
    public async Task Invalid_documents_are_rejected(string xml, int expectedCode)
    {
        var client = Client();
        if (xml.Length == 0)
        {
            // An empty body is refused by the API before the parser runs.
            var empty = await client.PostAsync("/api/validate", new StringContent("", Encoding.UTF8, "application/xml"));
            Assert.Equal(HttpStatusCode.BadRequest, empty.StatusCode);
            return;
        }
        var result = await PostJson(client, new { xml });
        Assert.Equal(Verdicts.Rejected, result.Verdict);
        Assert.Equal(expectedCode, result.Error!.Code);
    }

    [Fact]
    public async Task Invalid_utf8_is_rejected()
    {
        var bytes = new byte[] { (byte)'<', (byte)'a', (byte)'>', 0xC3, 0x28, (byte)'<', (byte)'/', (byte)'a', (byte)'>' };
        var response = await Client().PostAsync("/api/validate", new ByteArrayContent(bytes)
        {
            Headers = { ContentType = new MediaTypeHeaderValue("application/xml") },
        });
        var result = (await response.Content.ReadFromJsonAsync<ValidationResult>())!;
        Assert.Equal(Verdicts.Rejected, result.Verdict);
    }

    [Fact]
    public async Task File_upload_is_accepted()
    {
        using var form = new MultipartFormDataContent();
        form.Add(new ByteArrayContent(Encoding.UTF8.GetBytes("<catalog><item id='1'/></catalog>")), "file", "catalog.xml");
        form.Add(new StringContent("assertions"), "build");
        var response = await Client().PostAsync("/api/validate", form);
        var result = (await response.Content.ReadFromJsonAsync<ValidationResult>())!;

        Assert.Equal(Verdicts.Accepted, result.Verdict);
        Assert.Equal("assertions", result.Build);
        Assert.Equal(33, result.InputBytes);
    }

    [Theory]
    [InlineData("<root><a x='1'>text</a><!-- c --><b/></root>")]
    [InlineData("<root><a></root>")]
    [InlineData("<?xml version='1.0' encoding='UTF-8'?><r>&amp;&lt;&#x41;</r>")]
    public async Task Verdict_does_not_depend_on_chunk_size(string xml)
    {
        var client = Client();
        var whole = await PostJson(client, new { xml });
        foreach (int chunk in new[] { 1, 2, 3, 7 })
        {
            var chunked = await PostJson(client, new { xml, chunkSize = chunk });
            Assert.Equal("chunks", chunked.Mode);
            Assert.Equal(whole.Verdict, chunked.Verdict);
            Assert.Equal(whole.Error?.Code, chunked.Error?.Code);
            Assert.Equal(whole.Events.StartElements, chunked.Events.StartElements);
        }
    }

    [Fact]
    public async Task External_entities_are_never_loaded()
    {
        // win.ini exists on every Windows machine; its text must not reach the result.
        var result = await PostJson(Client(), new
        {
            xml = "<!DOCTYPE r [<!ENTITY x SYSTEM \"file:///C:/Windows/win.ini\">]><r>&x;</r>",
        });
        Assert.DoesNotContain(result.Events.Sample, e => e.Kind == "text");
        Assert.Equal(0, result.Events.TextChunks);
    }

    [Fact]
    public async Task Bad_requests_are_refused()
    {
        var client = Client(("Xpact:MaxDocumentBytes", "1000"));
        Assert.Equal(HttpStatusCode.BadRequest,
            (await client.PostAsJsonAsync("/api/validate", new { xml = "<a/>", build = "nope" })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest,
            (await client.PostAsJsonAsync("/api/validate", new { xml = "<a/>", chunkSize = -1 })).StatusCode);
        Assert.Equal(HttpStatusCode.RequestEntityTooLarge,
            (await client.PostAsJsonAsync("/api/validate", new { xml = "<a>" + new string('x', 2000) + "</a>" })).StatusCode);
    }

    [Fact]
    public async Task Slow_documents_are_stopped_by_the_timeout()
    {
        // Nested entities that expand to about 10^9 bytes ("billion laughs").
        var sb = new StringBuilder("<!DOCTYPE l [<!ENTITY a \"aaaaaaaaaa\">");
        string previous = "a";
        foreach (char name in "bcdefghi")
        {
            sb.Append($"<!ENTITY {name} \"{string.Concat(Enumerable.Repeat($"&{previous};", 10))}\">");
            previous = name.ToString();
        }
        sb.Append("]><l>&i;</l>");

        var result = await PostJson(Client(("Xpact:TimeoutSeconds", "3")), new { xml = sb.ToString() });

        // Either the parser refuses the expansion, or the API stops it: it never runs unbounded.
        Assert.Contains(result.Verdict, new[] { Verdicts.Rejected, Verdicts.Timeout, Verdicts.Crashed });
        Assert.True(result.TotalMs < 8000, $"took {result.TotalMs} ms");
    }

    [Fact]
    public async Task The_memory_cap_stops_a_worker_that_needs_more()
    {
        // Nested entities ("billion laughs", #211): under the normal 512 MB cap XPact rejects it,
        // but on the way its native memory grows past 40 MB. A tiny document needs about 28 MB (#227).
        var sb = new StringBuilder("<!DOCTYPE r [<!ENTITY a0 \"xxxxxxxxxx\">");
        for (int i = 1; i < 10; i++)
            sb.Append($"<!ENTITY a{i} \"").Append(string.Concat(Enumerable.Repeat($"&a{i - 1};", 10))).Append("\">");
        string laughs = sb.Append("]><r>&a9;</r>").ToString();
        var capped = Client(("Xpact:WorkerMemoryMb", "40"));

        Assert.Equal(Verdicts.Accepted, (await PostJson(capped, new { xml = "<a/>" })).Verdict);
        Assert.Equal(Verdicts.Rejected, (await PostJson(Client(), new { xml = laughs })).Verdict);

        var stopped = await PostJson(capped, new { xml = laughs });
        Assert.True(stopped.Verdict == Verdicts.Crashed, $"{stopped.Verdict}: {stopped.Diagnostic}");

        // The API keeps serving after the worker was stopped.
        Assert.Equal(Verdicts.Accepted, (await PostJson(capped, new { xml = "<a/>" })).Verdict);
    }

    [Fact]
    public async Task Results_files_are_served_and_names_are_checked()
    {
        var client = Client();
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/results/conformance")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/results/benchmarks")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/results/testing")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync("/api/results/appsettings")).StatusCode);
    }

    [Fact]
    public async Task Requests_are_rate_limited_per_client()
    {
        var client = Client(("Xpact:RequestsPerMinute", "2"));
        Assert.Equal(HttpStatusCode.OK, (await client.PostAsJsonAsync("/api/validate", new { xml = "<a/>" })).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await client.PostAsJsonAsync("/api/validate", new { xml = "<a/>" })).StatusCode);
        Assert.Equal(HttpStatusCode.TooManyRequests,
            (await client.PostAsJsonAsync("/api/validate", new { xml = "<a/>" })).StatusCode);
    }

    [Fact]
    public async Task Visitors_behind_a_proxy_are_rate_limited_separately()
    {
        var client = Client(("Xpact:RequestsPerMinute", "1"));
        Task<HttpResponseMessage> From(string visitor)
        {
            var request = new HttpRequestMessage(HttpMethod.Post, "/api/validate") { Content = JsonContent.Create(new { xml = "<a/>" }) };
            request.Headers.Add("X-Forwarded-For", visitor);
            return client.SendAsync(request);
        }
        Assert.Equal(HttpStatusCode.OK, (await From("203.0.113.1")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await From("203.0.113.2")).StatusCode);
        Assert.Equal(HttpStatusCode.TooManyRequests, (await From("203.0.113.1")).StatusCode);
    }

    [Fact]
    public async Task Security_headers_are_set()
    {
        var response = await Client().GetAsync("/api/health");
        Assert.Equal("nosniff", response.Headers.GetValues("X-Content-Type-Options").Single());
        Assert.Equal("DENY", response.Headers.GetValues("X-Frame-Options").Single());
    }
}
