namespace XpactDllTests;

internal sealed class Options
{
    public const string Usage = """
        XpactDllTests - test the xpact DLL through its C API (XML_Parse)

        Usage: XpactDllTests [options]

          --dll PATH         DLL to test (default: build\native-eiffel\xpact_assertions.dll)
          --out DIR          where results.tsv, summary.txt and crashes\ go
                             (default: build\dotnet-dll-tests\<dll>-<time>)
          --group LIST       c02, cr, utf8 (comma separated; default: all)
          --callbacks LIST   none, start, end, start+end, chardata, default
          --chunks LIST      whole, split, bytes
          --only TEXT        only cases whose id contains TEXT, e.g. c02-incomplete/start
          --isolate          one process per case (slower; use it to confirm a result)
          --jobs N           child processes running side by side (default: CPU count, max 8)
          --timeout SEC      a case that takes longer counts as TIMEOUT (default: 30)
          --verbose          print every case with its events
          --list             print the case ids and stop
          --help

        Exit code: 0 = every case passed, 1 = at least one FAIL, CRASH or TIMEOUT,
        2 = the run itself could not be done (bad option, DLL missing).
        """;

    public string DllPath = "";
    public string OutDir = "";
    public HashSet<string>? Groups;
    public HashSet<string>? Callbacks;
    public HashSet<string>? Chunks;
    public string? Only;
    public bool Isolate;
    public bool Verbose;
    public bool List;
    public bool Help;
    public int TimeoutSeconds = 30;
    public int Jobs = Math.Min(Environment.ProcessorCount, 8);

    // Child mode: run cases From, From + Stride, ... (at most Count) and report each one on stdout.
    public bool Child;
    public int From;
    public int Count = int.MaxValue;
    public int Stride = 1;

    /// <summary>The filter options, passed on unchanged so the child builds the same case list.</summary>
    public readonly List<string> FilterArgs = new();

    public static Options Parse(string[] args)
    {
        var o = new Options();
        string? dll = null, outDir = null;
        for (int i = 0; i < args.Length; i++)
        {
            string a = args[i];
            string Value()
            {
                if (i + 1 >= args.Length) throw new ArgumentException($"{a} needs a value");
                return args[++i];
            }
            switch (a)
            {
                case "--dll": dll = Value(); break;
                case "--out": outDir = Value(); break;
                case "--group": o.Groups = Set(a, Value(), Catalog.Groups, o); break;
                case "--callbacks": o.Callbacks = Set(a, Value(), Catalog.CallbackSets.Select(c => c.Name), o); break;
                case "--chunks": o.Chunks = Set(a, Value(), Catalog.ChunkKinds, o); break;
                case "--only": o.Only = Value(); o.FilterArgs.Add(a); o.FilterArgs.Add(o.Only); break;
                case "--isolate": o.Isolate = true; break;
                case "--timeout": o.TimeoutSeconds = int.Parse(Value()); break;
                case "--verbose": o.Verbose = true; break;
                case "--list": o.List = true; break;
                case "--help": case "-h": case "/?": o.Help = true; break;
                case "--child": o.Child = true; break;
                case "--from": o.From = int.Parse(Value()); break;
                case "--count": o.Count = int.Parse(Value()); break;
                case "--stride": o.Stride = Math.Max(1, int.Parse(Value())); break;
                case "--jobs": o.Jobs = Math.Max(1, int.Parse(Value())); break;
                default: throw new ArgumentException($"unknown option {a}");
            }
        }
        string root = RepoRoot();
        o.DllPath = Path.GetFullPath(dll ?? Path.Combine(root, "build", "native-eiffel", "xpact_assertions.dll"));
        o.OutDir = Path.GetFullPath(outDir ?? Path.Combine(root, "build", "dotnet-dll-tests",
            $"{Path.GetFileNameWithoutExtension(o.DllPath)}-{DateTime.Now:yyyyMMdd-HHmmss}"));
        return o;
    }

    private static HashSet<string> Set(string option, string value, IEnumerable<string> allowed, Options o)
    {
        var known = allowed.ToHashSet();
        var set = value.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).ToHashSet();
        foreach (string s in set)
        {
            if (!known.Contains(s)) throw new ArgumentException($"{option}: unknown value '{s}' (known: {string.Join(", ", known)})");
        }
        o.FilterArgs.Add(option);
        o.FilterArgs.Add(value);
        return set;
    }

    /// <summary>The folder with xpact.ecf, searched upwards from the program, else the current folder.</summary>
    public static string RepoRoot()
    {
        foreach (string start in new[] { AppContext.BaseDirectory, Environment.CurrentDirectory })
        {
            for (var d = new DirectoryInfo(start); d != null; d = d.Parent)
            {
                if (File.Exists(Path.Combine(d.FullName, "xpact.ecf"))) return d.FullName;
            }
        }
        return Environment.CurrentDirectory;
    }
}
