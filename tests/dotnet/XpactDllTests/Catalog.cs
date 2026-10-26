using System.Text;

namespace XpactDllTests;

internal enum Expect { Accept, Reject }

[Flags]
internal enum Cb { None = 0, Start = 1, End = 2, Text = 4, Default = 8 }

/// <summary>One input document and what a correct parser must do with it.</summary>
/// <param name="Elements">Start/end events of an accepted document, or null to not check them.</param>
/// <param name="Text">Character data of an accepted document (escaped), or null to not check it.</param>
/// <param name="ExpatError">Error code libexpat gives (reference only, not checked: verify in G03).</param>
internal sealed record InputCase(
    string Name, string Group, byte[] Bytes, Expect Expect, int ExpatError,
    string[]? Elements, string? Text, string Why);

internal sealed record CallbackSet(string Name, Cb Flags);

/// <summary>One XML_Parse call: a slice of the input and the isFinal flag.</summary>
internal sealed record Call(int Start, int Length, bool Final);

internal sealed record TestCase(
    int Index, string Id, InputCase Input, CallbackSet Callbacks,
    string Chunking, string ChunkKind, IReadOnlyList<Call> Calls);

internal static class Catalog
{
    // XML_Error codes from include/xpact.h
    public const int NoElements = 3, InvalidToken = 4, TagMismatch = 7, JunkAfterDocElement = 9;

    /// <summary>The callback configurations from task C02.</summary>
    public static readonly CallbackSet[] CallbackSets =
    {
        new("none", Cb.None),
        new("start", Cb.Start),
        new("end", Cb.End),
        new("start+end", Cb.Start | Cb.End),
        new("chardata", Cb.Text),
        new("default", Cb.Default),
    };

    public static readonly string[] ChunkKinds = { "whole", "split", "bytes" };

    public static readonly string[] Groups = { "c02", "cr", "utf8" };

    public static List<InputCase> Inputs()
    {
        var list = new List<InputCase>();
        string[] root = { "start:root", "end:root" };
        string[] r = { "start:r", "end:r" };

        // C02: the guide's "first test matrix" (docs/xpact-student-introduction.md).
        list.Add(new("c02-valid", "c02", B("<root/>"), Expect.Accept, 0, root, "", "complete empty root"));
        list.Add(new("c02-valid-pair", "c02", B("<root></root>"), Expect.Accept, 0, root, "", "complete root, start and end tag"));
        list.Add(new("c02-text", "c02", B("<root>hi</root>"), Expect.Accept, 0, root, "hi", "control for the chardata callback"));
        list.Add(new("c02-empty", "c02", B(""), Expect.Reject, NoElements, null, null, "no root element"));
        list.Add(new("c02-incomplete", "c02", B("<root>"), Expect.Reject, NoElements, null, null, "root never closed (C01 shortcut accepted it in June)"));
        list.Add(new("c02-mismatched", "c02", B("<root><child></root>"), Expect.Reject, TagMismatch, null, null, "end tag does not match"));
        list.Add(new("c02-trailing-junk", "c02", B("<root/>junk"), Expect.Reject, JunkAfterDocElement, null, null, "text after the root element"));

        // CR line ends (#28). XML turns CR LF and a lone CR into LF.
        list.Add(new("cr-crlf", "cr", B("<r>\r\n</r>"), Expect.Accept, 0, r, "\\x0a", "CR LF -> LF"));
        list.Add(new("cr-lone", "cr", B("<r>\r</r>"), Expect.Accept, 0, r, "\\x0a", "lone CR -> LF"));
        list.Add(new("cr-last-byte", "cr", B("<r/>\r"), Expect.Accept, 0, r, "", "CR after the root"));
        list.Add(new("cr-attribute", "cr", B("<r a='x\ry'/>"), Expect.Accept, 0, r, "", "CR in an attribute value"));

        // C10 (part): UTF-8 sequences in every context. valid-e9 is the control:
        // if it is rejected too, the parser rejects all non-ASCII, which is a different bug.
        var sequences = new (string Name, byte[] Bytes, bool Valid, string Why)[]
        {
            ("valid-e9", new byte[] { 0xC3, 0xA9 }, true, "valid U+00E9 (control)"),
            ("bad-continuation", new byte[] { 0xC3, 0x28 }, false, "lead byte without continuation byte"),
            ("overlong", new byte[] { 0xC0, 0xAF }, false, "overlong encoding of '/'"),
            ("surrogate", new byte[] { 0xED, 0xA0, 0x80 }, false, "UTF-16 surrogate U+D800"),
            ("above-10ffff", new byte[] { 0xF4, 0x90, 0x80, 0x80 }, false, "code point above U+10FFFF"),
            ("lone-continuation", new byte[] { 0x80 }, false, "continuation byte without a lead byte"),
            ("ff", new byte[] { 0xFF }, false, "byte FF, never valid in UTF-8"),
        };
        var contexts = new (string Name, string Before, string After)[]
        {
            ("text", "<r>", "</r>"),
            ("attribute", "<r a='", "'/>"),
            ("name", "<r", "/>"),
            ("comment", "<r><!--", "--></r>"),
            ("pi", "<r><?pi ", "?></r>"),
            ("cdata", "<r><![CDATA[", "]]></r>"),
        };
        foreach (var seq in sequences)
        {
            foreach (var ctx in contexts)
            {
                byte[] bytes = Concat(B(ctx.Before), seq.Bytes, B(ctx.After));
                string name = $"utf8-{seq.Name}-{ctx.Name}";
                if (seq.Valid)
                {
                    string esc = XpactDllTests.Bytes.Escape(seq.Bytes);
                    string[] elements = ctx.Name == "name" ? new[] { $"start:r{esc}", $"end:r{esc}" } : r;
                    string text = ctx.Name is "text" or "cdata" ? esc : "";
                    list.Add(new(name, "utf8", bytes, Expect.Accept, 0, elements, text, $"{seq.Why} in {ctx.Name}"));
                }
                else
                {
                    list.Add(new(name, "utf8", bytes, Expect.Reject, InvalidToken, null, null, $"{seq.Why} in {ctx.Name}"));
                }
            }
        }
        return list;
    }

    /// <summary>All test cases matching the filters, in a fixed order (parent and child must agree).</summary>
    public static List<TestCase> Build(Options o)
    {
        var cases = new List<TestCase>();
        foreach (var input in Inputs())
        {
            if (o.Groups != null && !o.Groups.Contains(input.Group)) continue;
            foreach (var cb in CallbackSets)
            {
                if (o.Callbacks != null && !o.Callbacks.Contains(cb.Name)) continue;
                foreach (var (chunking, kind, calls) in Plans(input.Bytes.Length))
                {
                    if (o.Chunks != null && !o.Chunks.Contains(kind)) continue;
                    string id = $"{input.Name}/{cb.Name}/{chunking}";
                    if (o.Only != null && !id.Contains(o.Only, StringComparison.OrdinalIgnoreCase)) continue;
                    cases.Add(new TestCase(cases.Count, id, input, cb, chunking, kind, calls));
                }
            }
        }
        return cases;
    }

    /// <summary>
    /// whole: one final call. split@k: bytes [0,k) non-final, then the rest final (C03).
    /// bytes: one non-final call per byte, then an empty final call.
    /// </summary>
    private static IEnumerable<(string Name, string Kind, IReadOnlyList<Call> Calls)> Plans(int n)
    {
        yield return ("whole", "whole", new[] { new Call(0, n, true) });
        for (int k = 1; k < n; k++)
        {
            yield return ($"split@{k}", "split", new[] { new Call(0, k, false), new Call(k, n - k, true) });
        }
        if (n > 0)
        {
            var calls = new List<Call>();
            for (int i = 0; i < n; i++) calls.Add(new Call(i, 1, false));
            calls.Add(new Call(n, 0, true));
            yield return ("bytes", "bytes", calls);
        }
    }

    private static byte[] B(string ascii) => Encoding.Latin1.GetBytes(ascii);

    private static byte[] Concat(params byte[][] parts) => parts.SelectMany(p => p).ToArray();
}
