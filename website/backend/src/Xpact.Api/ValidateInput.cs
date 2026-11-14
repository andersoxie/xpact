using System.Text;

namespace Xpact.Api;

/// <summary>The three accepted request shapes: multipart form, JSON, or a raw XML body.</summary>
internal sealed record ValidateInput(byte[]? Document, string? Build, int? ChunkSize)
{
    public static async Task<ValidateInput> ReadAsync(HttpRequest http, CancellationToken cancellationToken)
    {
        string? build = http.Query["build"];
        int? chunk = int.TryParse(http.Query["chunkSize"], out int q) ? q : null;

        if (http.HasFormContentType)
        {
            var form = await http.ReadFormAsync(cancellationToken);
            build = form["build"].FirstOrDefault() ?? build;
            if (int.TryParse(form["chunkSize"].FirstOrDefault(), out int f)) chunk = f;
            if (form.Files.GetFile("file") is { } file)
            {
                // One exactly sized copy (#357); the form's own buffer is bounded by the request size.
                byte[] bytes = new byte[file.Length];
                await using var stream = file.OpenReadStream();
                await stream.ReadExactlyAsync(bytes, cancellationToken);
                return new ValidateInput(bytes, build, chunk);
            }
            string? text = form["xml"].FirstOrDefault();
            return new ValidateInput(text is null ? null : Encoding.UTF8.GetBytes(text), build, chunk);
        }

        if (http.HasJsonContentType())
        {
            var body = await http.ReadFromJsonAsync<JsonBody>(cancellationToken);
            return new ValidateInput(body?.Xml is null ? null : Encoding.UTF8.GetBytes(body.Xml),
                body?.Build ?? build, body?.ChunkSize ?? chunk);
        }

        // Raw body (for example curl --data-binary @file.xml -H "Content-Type: application/xml").
        // With a Content-Length (already checked against the body limit) read into one exact array (#357).
        if (http.ContentLength is > 0 and <= int.MaxValue)
        {
            byte[] exact = new byte[(int)http.ContentLength.Value];
            await http.Body.ReadExactlyAsync(exact, cancellationToken);
            return new ValidateInput(exact, build, chunk);
        }
        using var raw = new MemoryStream();
        await http.Body.CopyToAsync(raw, cancellationToken);
        return new ValidateInput(raw.Length == 0 ? null : raw.ToArray(), build, chunk);
    }

    private sealed record JsonBody(string? Xml, string? Build, int? ChunkSize);
}
