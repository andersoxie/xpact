import { LINKS, repoFile } from "../data/site";

const SECTIONS = [
  ["overview", "Overview"],
  ["install", "Installation"],
  ["c-api", "C API"],
  ["example-c", "Example: C"],
  ["example-cs", "Example: C#"],
  ["rest", "Website REST API"],
  ["features", "Supported features"],
  ["limits", "Known limitations"],
] as const;

const API: [string, string][] = [
  ["XML_ParserCreate(encoding)", "Create a parser. encoding may be NULL (detect from the document)."],
  ["XML_ParserCreateNS(encoding, sep)", "Create a parser with namespace processing; names become uri + sep + local."],
  ["XML_SetElementHandler / XML_SetStartElementHandler / XML_SetEndElementHandler", "Called for each start and end tag (name, attributes)."],
  ["XML_SetCharacterDataHandler", "Called for text. Text may arrive in several pieces."],
  ["XML_SetCommentHandler, XML_SetProcessingInstructionHandler", "Comments and <?target data?>."],
  ["XML_SetDefaultHandler", "Everything that has no other handler, as raw text."],
  ["XML_SetExternalEntityRefHandler", "Lets your program load external entities. Without it, nothing outside the document is read."],
  ["XML_SetUserData", "A pointer passed to every handler."],
  ["XML_Parse(parser, s, len, isFinal)", "Parse the next piece of the document. Call it as often as you like; the last call has isFinal = 1."],
  ["XML_StopParser / XML_ResumeParser", "Stop or suspend parsing from inside a handler."],
  ["XML_GetErrorCode, XML_ErrorString", "Why parsing failed: an Expat-compatible code and its text."],
  ["XML_GetCurrentLineNumber, XML_GetCurrentColumnNumber, XML_GetCurrentByteIndex", "Where the parser is (or where the error is)."],
  ["XML_ParserReset, XML_ParserFree", "Reuse or release a parser."],
  ["XML_ExpatVersion", "The API version string (XPact reports the Expat version it follows)."],
];

export function Docs() {
  return (
    <>
      <div className="page-head">
        <h1>Documentation</h1>
        <p>
          How to build XPact and use it from your own program. The full C header is{" "}
          <a href={LINKS.header}>include/xpact.h</a>; the design is described in the repository's{" "}
          <a href={repoFile("docs/design-overview.md")}>design overview</a>.
        </p>
      </div>

      <div className="docs">
        <nav className="toc" aria-label="On this page">
          {SECTIONS.map(([id, label]) => (
            <a key={id} href={`#${id}`}>
              {label}
            </a>
          ))}
        </nav>

        <div>
          <section id="overview">
            <h2>Overview</h2>
            <p>XPact has two layers:</p>
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Layer</th>
                    <th>Language</th>
                    <th>Use it when</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td>The parser (<code>XP_PARSER</code>)</td>
                    <td>Eiffel</td>
                    <td>Your program is written in Eiffel</td>
                  </tr>
                  <tr>
                    <td>The C library (<code>xpact.dll</code> + <code>xpact.h</code>)</td>
                    <td>Eiffel, compiled to C</td>
                    <td>Your program is written in C, C++, C# or anything that can call a C library</td>
                  </tr>
                </tbody>
              </table>
            </div>
            <p style={{ marginTop: 12 }}>
              There are two builds of the library: <strong>production</strong> (<code>xpact.dll</code>, contracts
              off, faster) and <strong>assertions</strong> (<code>xpact_assertions.dll</code>, every contract checked,
              for testing).
            </p>
          </section>

          <section id="install">
            <h2>Installation</h2>
            <p>You need Windows x64, EiffelStudio 25.x and Visual Studio's C++ tools (MSVC).</p>
            <pre>
              <code>{`git clone ${LINKS.repo}.git
cd xpact
git checkout student-Mass

# Build the C library (both builds)
.\\scripts\\build_native_eiffel.ps1 -BuildTier Production
.\\scripts\\build_native_eiffel.ps1 -BuildTier Assertions

# Result:
#   build\\native-eiffel\\xpact.dll   xpact.lib
#   build\\native-eiffel\\xpact_assertions.dll   xpact_assertions.lib`}</code>
            </pre>
            <p>
              Link your program with <code>xpact.lib</code>, include <code>include/xpact.h</code>, and ship{" "}
              <code>xpact.dll</code> next to your executable. See{" "}
              <a href={repoFile("docs/windows-release.md")}>windows-release.md</a> for a packaged release.
            </p>
          </section>

          <section id="c-api">
            <h2>C API</h2>
            <p>
              The library follows the Expat API, so Expat's documentation also applies. The functions most programs
              need:
            </p>
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Function</th>
                    <th>Purpose</th>
                  </tr>
                </thead>
                <tbody>
                  {API.map(([fn, purpose]) => (
                    <tr key={fn}>
                      <td>
                        <code>{fn}</code>
                      </td>
                      <td>{purpose}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <p className="small muted" style={{ marginTop: 10 }}>
              Coverage of the whole Expat API: <a href={repoFile("docs/libexpat-api-compatibility.md")}>libexpat-api-compatibility.md</a>.
            </p>
          </section>

          <section id="example-c">
            <h2>Example: C</h2>
            <pre>
              <code>{`#include <stdio.h>
#include <string.h>
#include "xpact.h"

static void XMLCALL on_start(void *data, const XML_Char *name, const XML_Char **atts) {
    int *depth = data;
    printf("%*s<%s>\\n", 2 * (*depth)++, "", name);
}

static void XMLCALL on_end(void *data, const XML_Char *name) {
    int *depth = data;
    --*depth;
}

int main(void) {
    const char *xml = "<catalog><book id=\\"1\\"/><book id=\\"2\\"/></catalog>";
    int depth = 0;
    XML_Parser p = XML_ParserCreate(NULL);
    XML_SetUserData(p, &depth);
    XML_SetElementHandler(p, on_start, on_end);

    if (XML_Parse(p, xml, (int)strlen(xml), 1) == XML_STATUS_ERROR) {
        fprintf(stderr, "error %d: %s at line %lu, column %lu\\n",
                XML_GetErrorCode(p), XML_ErrorString(XML_GetErrorCode(p)),
                XML_GetCurrentLineNumber(p), XML_GetCurrentColumnNumber(p));
    }
    XML_ParserFree(p);
    return 0;
}`}</code>
            </pre>
            <p className="small muted">
              Build: <code>cl /I include example.c build\native-eiffel\xpact.lib</code>
            </p>
          </section>

          <section id="example-cs">
            <h2>Example: C#</h2>
            <p>
              The website itself calls XPact from C# with P/Invoke (<a href={repoFile("website/backend/src/Xpact.Worker/Native.cs")}>Native.cs</a>):
            </p>
            <pre>
              <code>{`[DllImport("xpact", CallingConvention = CallingConvention.Cdecl)]
static extern IntPtr XML_ParserCreate(byte* encoding);

[DllImport("xpact", CallingConvention = CallingConvention.Cdecl)]
static extern int XML_Parse(IntPtr parser, byte* s, int len, int isFinal);

IntPtr p = XML_ParserCreate(null);
fixed (byte* bytes = document)
    ok = XML_Parse(p, bytes, document.Length, 1) == 1;`}</code>
            </pre>
          </section>

          <section id="rest">
            <h2>Website REST API</h2>
            <p>The validator on this site is a thin client of a small REST API you can call yourself:</p>
            <pre>
              <code>{`# Raw XML body
curl --data-binary @example.xml -H "Content-Type: application/xml" \\
     "http://localhost:5080/api/validate?build=production"

# JSON
curl -H "Content-Type: application/json" \\
     -d '{"xml":"<a><b></a>","build":"assertions","chunkSize":1}' \\
     http://localhost:5080/api/validate`}</code>
            </pre>
            <p>
              Response fields, limits and error codes: <a href={repoFile("website/docs/api.md")}>website/docs/api.md</a>.
            </p>
          </section>

          <section id="features">
            <h2>Supported features</h2>
            <ul className="check-list">
              <li><span className="tick">✅</span> XML 1.0, fifth edition: well-formedness checking (non-validating)</li>
              <li><span className="tick">✅</span> Encodings: UTF-8, UTF-16 (with BOM), ISO-8859-1, US-ASCII</li>
              <li><span className="tick">✅</span> Internal DTD subset: entity and attribute-list declarations, default attributes</li>
              <li><span className="tick">✅</span> Namespaces (<code>XML_ParserCreateNS</code>)</li>
              <li><span className="tick">✅</span> External entities and DTDs, only when your program loads them (<code>XML_SetExternalEntityRefHandler</code>)</li>
              <li><span className="tick">✅</span> Incremental parsing: the document may arrive in pieces of any size</li>
              <li><span className="todo">⬜</span> XML 1.1: documents are processed as XML 1.0 (as XML 1.0 §2.8 requires)</li>
              <li><span className="todo">⬜</span> DTD validation (validity constraints): not done; XPact is non-validating, like Expat</li>
            </ul>
          </section>

          <section id="limits">
            <h2>Known limitations</h2>
            <p className="muted">Open issues, with their tracking numbers. Each one has a report in the repository.</p>
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Limitation</th>
                    <th>Effect</th>
                    <th>Issue</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td>Incremental parsing through the DLL re-reads the buffered input on each call</td>
                    <td>Feeding a document in very small pieces is slow (8 KB byte by byte: about a minute; Expat: milliseconds)</td>
                    <td>F05-1</td>
                  </tr>
                  <tr>
                    <td>Deeply nested entity expansion (“billion laughs”) is cut off late, with a general code</td>
                    <td>
                      A 10 MB+ expansion is rejected after about 7 s as “syntax error”; Expat rejects it in about 0.1 s as
                      “amplification limit breached”
                    </td>
                    <td><a href={LINKS.issue(211)}>#211</a></td>
                  </tr>
                  <tr>
                    <td>Some error codes differ from Expat</td>
                    <td>Same accept/reject verdict, a different code in 14 W3C cases</td>
                    <td><a href={LINKS.issue(170)}>#170</a></td>
                  </tr>
                  <tr>
                    <td>Error columns</td>
                    <td>The column of an error can differ from Expat's</td>
                    <td><a href={LINKS.issue(171)}>#171</a></td>
                  </tr>
                  <tr>
                    <td><code>]]&gt;</code> split across pieces; some CDATA events before a UTF-8 error</td>
                    <td>Events can differ from Expat when the document is fed in pieces</td>
                    <td>
                      <a href={LINKS.issue(176)}>#176</a>, <a href={LINKS.issue(123)}>#123</a>
                    </td>
                  </tr>
                  <tr>
                    <td>Raw carriage returns to the default handler</td>
                    <td>The default handler gets normalised line ends; Expat passes the raw CR</td>
                    <td><a href={LINKS.issue(126)}>#126</a></td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>
        </div>
      </div>
    </>
  );
}
