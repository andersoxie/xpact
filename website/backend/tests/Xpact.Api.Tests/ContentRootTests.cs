using Xpact.Api;

namespace Xpact.Api.Tests;

/// <summary>#455 / PR #461 review: the exe folder is only the default content root; an explicit root wins.</summary>
public sealed class ContentRootTests : IDisposable
{
    private readonly string _exeDir = Directory.CreateTempSubdirectory("xpact-root-").FullName;
    private static readonly Dictionary<string, string?> NoEnv = [];

    public void Dispose() => Directory.Delete(_exeDir, recursive: true);

    private void AddBuiltSite()
    {
        Directory.CreateDirectory(Path.Combine(_exeDir, "wwwroot"));
        File.WriteAllText(Path.Combine(_exeDir, "wwwroot", "index.html"), "<!doctype html>");
    }

    [Fact]
    public void Exe_folder_with_built_site_is_the_default()
    {
        AddBuiltSite();
        Assert.Equal(_exeDir, ContentRoot.Fallback([], _exeDir, NoEnv));
    }

    [Fact]
    public void Exe_folder_without_built_site_keeps_the_host_default() =>
        Assert.Null(ContentRoot.Fallback([], _exeDir, NoEnv));

    [Theory]
    [InlineData("--contentRoot", "C:\\site")]
    [InlineData("--contentroot", "C:\\site")]
    [InlineData("/contentRoot", "C:\\site")]
    [InlineData("--contentRoot=C:\\site", null)]
    public void Command_line_root_wins(string first, string? second)
    {
        AddBuiltSite();
        string[] args = second is null ? [first] : [first, second];
        Assert.Null(ContentRoot.Fallback(args, _exeDir, NoEnv));
    }

    [Theory]
    [InlineData("DOTNET_CONTENTROOT")]
    [InlineData("ASPNETCORE_CONTENTROOT")]
    [InlineData("aspnetcore_contentRoot")]
    public void Environment_root_wins(string name)
    {
        AddBuiltSite();
        Assert.Null(ContentRoot.Fallback([], _exeDir, new Dictionary<string, string?> { [name] = "C:\\site" }));
    }

    [Fact]
    public void Empty_or_unrelated_settings_are_not_an_override()
    {
        AddBuiltSite();
        var env = new Dictionary<string, string?> { ["DOTNET_CONTENTROOT"] = "", ["ASPNETCORE_ENVIRONMENT"] = "Production" };
        Assert.Equal(_exeDir, ContentRoot.Fallback(["--urls", "http://localhost:5099"], _exeDir, env));
    }
}
