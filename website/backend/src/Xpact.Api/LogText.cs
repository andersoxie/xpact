namespace Xpact.Api;

/// <summary>
/// Makes a value safe to put in one log line (#424, CodeQL cs/log-forging). A line break in a value
/// that can come from a visitor (or from the worker's error output) could otherwise add a fake line
/// to the server log. Line breaks become " | "; any other control character becomes '?'.
/// </summary>
public static class LogText
{
    public static string OneLine(string? value)
    {
        // Return a new empty string, never the input itself: every path out of here is cleaned.
        if (string.IsNullOrEmpty(value)) return "";
        string oneLine = value.Replace("\r\n", " | ").Replace("\r", " | ").Replace("\n", " | ");
        return string.Create(oneLine.Length, oneLine, static (span, source) =>
        {
            for (int i = 0; i < source.Length; i++)
                span[i] = char.IsControl(source[i]) ? '?' : source[i];
        });
    }
}
