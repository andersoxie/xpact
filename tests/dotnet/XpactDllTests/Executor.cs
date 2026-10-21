namespace XpactDllTests;

/// <summary>What the DLL did with one test case. Sent from the child to the parent as JSON.</summary>
internal sealed class RunOutcome
{
    /// <summary>ACCEPT, REJECT, SUSPENDED or CREATE_FAILED.</summary>
    public string Verdict { get; set; } = "";
    public int ErrorCode { get; set; }
    public string ErrorString { get; set; } = "";
    public uint Line { get; set; }
    public uint Column { get; set; }
    public int ByteIndex { get; set; }
    /// <summary>1-based number of the XML_Parse call that did not return OK, 0 if all did.</summary>
    public int FailedCall { get; set; }
    public int CallCount { get; set; }
    public List<string> Events { get; set; } = new();
}

internal static unsafe class Executor
{
    public static RunOutcome Run(TestCase t)
    {
        Recorder.Events.Clear();
        var result = new RunOutcome { CallCount = t.Calls.Count };

        IntPtr parser = Native.XML_ParserCreate(null);
        if (parser == IntPtr.Zero)
        {
            result.Verdict = "CREATE_FAILED";
            return result;
        }
        try
        {
            Cb flags = t.Callbacks.Flags;
            if (flags.HasFlag(Cb.Start)) Native.XML_SetStartElementHandler(parser, &Recorder.OnStart);
            if (flags.HasFlag(Cb.End)) Native.XML_SetEndElementHandler(parser, &Recorder.OnEnd);
            if (flags.HasFlag(Cb.Text)) Native.XML_SetCharacterDataHandler(parser, &Recorder.OnText);
            if (flags.HasFlag(Cb.Default)) Native.XML_SetDefaultHandler(parser, &Recorder.OnDefault);

            // One spare byte, so an empty input still has a valid pointer.
            byte[] buffer = new byte[t.Input.Bytes.Length + 1];
            t.Input.Bytes.CopyTo(buffer, 0);

            int status = Native.StatusOk;
            fixed (byte* p = buffer)
            {
                for (int i = 0; i < t.Calls.Count; i++)
                {
                    Call c = t.Calls[i];
                    status = Native.XML_Parse(parser, p + c.Start, c.Length, c.Final ? 1 : 0);
                    if (status != Native.StatusOk)
                    {
                        result.FailedCall = i + 1;
                        break;
                    }
                }
            }

            result.Verdict = status switch
            {
                Native.StatusOk => "ACCEPT",
                Native.StatusError => "REJECT",
                Native.StatusSuspended => "SUSPENDED",
                _ => $"STATUS_{status}",
            };
            if (status != Native.StatusOk)
            {
                result.ErrorCode = Native.XML_GetErrorCode(parser);
                result.ErrorString = Native.CString(Native.XML_ErrorString(result.ErrorCode));
                result.Line = Native.XML_GetCurrentLineNumber(parser);
                result.Column = Native.XML_GetCurrentColumnNumber(parser);
                result.ByteIndex = Native.XML_GetCurrentByteIndex(parser);
            }
            result.Events = new List<string>(Recorder.Events);
            return result;
        }
        finally
        {
            Native.XML_ParserFree(parser);
        }
    }
}
