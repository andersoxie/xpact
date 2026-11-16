using Xpact.Api;

namespace Xpact.Api.Tests;

/// <summary>#424: a value written to the log can never start a new log line.</summary>
public class LogTextTests
{
    [Theory]
    [InlineData("production", "production")]
    [InlineData("127.0.0.1", "127.0.0.1")]
    [InlineData("a\r\nINFO: admin logged in", "a | INFO: admin logged in")]
    [InlineData("a\nb\rc", "a | b | c")]
    [InlineData("tab\there\u0007bell\u001b[31m", "tab?here?bell?[31m")]
    [InlineData("", "")]
    public void Values_stay_on_one_line(string input, string expected) =>
        Assert.Equal(expected, LogText.OneLine(input));

    [Fact]
    public void Null_becomes_empty() => Assert.Equal("", LogText.OneLine(null));

    [Fact]
    public void No_line_break_or_control_character_survives()
    {
        string all = new(Enumerable.Range(0, 0x30).Select(i => (char)i).ToArray());
        Assert.DoesNotContain(LogText.OneLine(all), char.IsControl);
    }
}
