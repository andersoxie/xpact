# Windows DLL profile, 23 November 2026

**Optimize chunked ISO-8859-1 (Latin-1) first.** When fed a 132,422-byte document
in 4 KiB pieces, xpact took **456.2 ms** and libexpat took **2.10 ms**. xpact
decoded each growing prefix and repeatedly parsed the elements it had already
seen. For UTF-8 applications, the next candidate is the cost of constructing
namespace scopes on start tags.

## Where the time goes

These are median milliseconds per document from five uninstrumented Windows
x64 runs. The three smaller-document rows contain the same XML text, including
accented characters. The namespace rows use the exact same input bytes.

| Input and delivery | Callbacks | xpact | libexpat 2.8.1 | Extra time |
|---|---|---:|---:|---:|
| Latin-1 elements, 132 KB, whole document | On | 22.80 | 1.89 | 20.91 |
| Latin-1 elements, 132 KB, 4 KiB pieces | On | 456.21 | 2.10 | 454.10 |
| UTF-8 elements, 134 KB, 4 KiB pieces | On | 27.73 | 2.15 | 25.58 |
| UTF-8 namespace fixture, 1 MB, 4 KiB pieces, namespace processing off | Off | 67.56 | 10.84 | 56.72 |
| Same, namespace processing on | Off | 231.17 | 13.35 | 217.81 |
| UTF-8 elements, 1 MB, 4 KiB pieces | Off | 111.37 | 14.19 | 97.19 |
| Same, element and text handlers registered | On | 213.99 | 16.06 | 197.93 |

**Latin-1.** A separate diagnostic build counted the bytes passed into the
decoder and parser for one document. Across 33 calls, the Latin-1 decoder
read **2,295,110 raw bytes**. The parser processed 32 growing prefixes and one
final document, totaling **2,319,780 decoded bytes**, or **17.3 times** the
decoded document length. On the equivalent UTF-8 input, xpact parsed one
initial prefix and 32 continuations totaling **133,836 bytes**, exactly one
document. All these parses produced the same callback checksum.

The sampled stacks locate the extra work. Of 1,889 xpact Latin-1 stacks,
**65.4%** included `XP_PARSER.parse_prefix`, **25.1%** included
`pending_markup_start`, and **5.5%** included the Latin-1 decoder. In
libexpat, 89.8% of 1,666 stacks included `doContent` and 3.9% included
`latin1_toUtf8`. A faster byte-conversion loop alone would leave the repeated
XML parsing in place. As input grew from approximately 33 to 66 to 132 KB at a
fixed 4 KiB feed size, xpact took 36, 124 and 456 ms. [Parser fallback and checkpoint selection][native]

**UTF-8 namespaces.** Enabling namespaces on identical bytes added **163.6 ms**
for xpact and **2.5 ms** for libexpat, even with application callbacks off.
Of 1,949 xpact stacks with namespaces on, 66.5% included `parse_start_tag`,
16.5% included `namespace_scope_for_element`, and 13.1% included qualified-name
validation. The scope routine deep-copies inherited bindings for every start
tag, including tags that introduce no declarations. Try reusing the parent
scope on those tags, and make a private scope before changing a binding.
Preserve nested prefix rebinding, default-namespace changes and callback
ownership of mutable strings. The 16.5% includes all work in the scope
routine and its callees. It is an upper bound on the share this change could
remove from this profile. [Namespace scope construction][scope]

**UTF-8 callbacks.** Enabling the stock element and text callbacks added
**102.6 ms** for xpact and **1.9 ms** for libexpat on the 1 MB elements file.
With callbacks on, 40.6% of xpact stacks included `parse_start_tag`, 22.2%
included `pending_markup_start`, and 6.6% included the start-element handler.
Enabling handlers also changes the parser's work to materialize names, text
and attributes. Attributing the entire difference to the C call would
overstate the bridge cost. [Raw timings](timings.csv) · [Symbol counts](measurements.json)

## First change and acceptance criteria

1. **Establish the Latin-1 position baseline.** On four short fixtures with
   accented text and CRLF, xpact and Expat agreed on all **214** verdicts,
   error codes, and coalesced event streams across whole and split feeds.
   At least one element position and the terminal position differed in every
   run. For the declared-encoding mismatched end tag, xpact reported byte
   **71**, line 2, column **12**. Expat reported byte **69**, line 2, column
   **11**. Use the raw-byte positions, line and column from Expat as the oracle.
2. **Extend the checkpoint to stable Latin-1 input.** Decode the new suffix
   and continue from the last committed parser position. Track raw bytes
   consumed and decoded UTF-8 bytes consumed separately. Commit the cursors
   and callback progress together after a successful advance. Preserve the
   pending token and delivery state across suspension. Invalidate the
   checkpoint on terminal error, completion, reset and free. Keep the final
   error location and input context available for as long as the API requires,
   and verify the lifetime of the decoded buffer separately. Keep the fallback
   for unresolved encodings and unsupported parser states. [Existing continuation logic][native]
3. **Require both correctness and a change in the amount of work.** Repeat
   the four fixtures with the encoding declared and explicitly selected, at
   every split and with an empty final call. Add suspend → resume and failed
   parse → reset → successful parse → free sequences, and exercise both
   `XML_Parse` and `XML_GetBuffer`/`XML_ParseBuffer`. Compare callback order,
   raw positions, error codes and input context to Expat. Run the DLL tests
   with assertions on and off. For performance, rerun the stock harness and
   the byte counters at 33, 66 and 132 KB with 4 KiB feeds. The parser should
   consume each completed prefix once and elapsed time should grow roughly
   with input length. Track the UTF-8 controls for regressions.

The existing C API suite passed **4,308/4,308 on each measured DLL**, including
agreement on verdict, error code and error position. The per-case comparison
still shows 171 different event traces after joining adjacent text, two
text-splitting-only differences and 648 differences in which call reported
an error. The 214 Latin-1 feed cases exercise position behavior outside that
suite. The performance changes above are proposals. [Measurements and fixture verdicts](measurements.json)

## How to interpret or repeat the measurements

The production DLL was built from `main` at `cef191d` (xpact 0.10.0) using
EiffelStudio 25.02.9.8723, finalized with assertions off. The reference was
native Expat 2.8.1, revision `7ed8230`, built with MSVC 19.44 in Release
mode. Both ran single-threaded on the same AMD Ryzen Threadripper 3970X
Windows x64 host. These measurements cover the EiffelStudio DLL.

- The unmodified C harness loaded either DLL. Each timed iteration created a
  parser, passed the input via `XML_Parse` and freed it. It excluded file I/O.
  After one calibration run, engine order alternated across five rounds per
  configuration. All 18 configurations completed. Every callback-enabled
  pair matched on the hash of element names, attributes and text. [Harness][harness] · [All five rounds](timings.csv)
- The 1 MB inputs are the repository's standard generated fixtures. For the
  smaller fixtures, generate the elements document targeting 32, 64 or 128
  KiB, insert `é` after each opening `<value>`, then serialize the same text
  with its matching UTF-8 or ISO-8859-1 declaration. [Input generator][generator]
- A separate executable sampled its own benchmark thread at a nominal 1 ms
  interval during the timed region. Ten runs across both DLLs yielded
  **17,138 stacks**, zero capture errors and two unidentified leaf frames.
  Percentages use all stacks for the indicated run. Inclusive counts overlap
  and include callees. The timings come from the separate uninstrumented
  runs. Exact DLL and linker-map hashes, fixture sizes, individual byte counts
  and resolved symbol counts are in the [measurement record](measurements.json).

[native]: https://github.com/andersoxie/xpact/blob/cef191df2c9e5786212b814e4d666d5c52fe28c0/src/xp_native_parser.e#L989
[scope]: https://github.com/andersoxie/xpact/blob/cef191df2c9e5786212b814e4d666d5c52fe28c0/src/xp_parser.e#L6742
[harness]: https://github.com/andersoxie/xpact/blob/cef191df2c9e5786212b814e4d666d5c52fe28c0/benchmarks/fair_speed/fair_speed.c
[generator]: https://github.com/andersoxie/xpact/blob/cef191df2c9e5786212b814e4d666d5c52fe28c0/benchmarks/fair_speed/gen_inputs.py
