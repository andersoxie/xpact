# Report: mass-xpact #53: without a character-data handler, a long text run in pieces was parsed again every call

> **Issue:** [CodTanium/mass-xpact#53](https://github.com/CodTanium/mass-xpact/issues/53) · **Branch:** `perf/53-plain-text-shortcut`, from `student-Mass` @ `270db12`
> **Changed:** `src/xp_parser.e` (one query), `src/xp_native_parser.e` (when the plain-text shortcut starts)
> **Status:** ✅ fixed · ✅ verified (see section 4)

## 1. In short

With no character-data handler, a text run that reached the end of a chunk was parsed again from
its start on the next call. That made a long run quadratic: 100 KB in 16-byte pieces took 1.6 s.
The native parser already had a shortcut for this. New plain ASCII text bytes are only counted,
and parsed in one go once other bytes arrive. It was enabled only when the input so far was
exactly one start tag. It is now also enabled when the last parse ended inside a plain text run
of an open element, for encodings where one raw ASCII byte is one character.

| No handlers, `<a>` + N KB of `x` + `</a>` | Before (#51) | After | |
|---|---:|---:|---|
| 25 KB, 16-byte pieces | 102 ms | **1.7 ms** | 62× |
| 50 KB, 16-byte pieces | 399 ms | **2.7 ms** | 150× |
| 100 KB, 16-byte pieces | 1,622 ms | **3.6 ms** | **450×** |
| 100 KB, 64-byte pieces | 424 ms | **3.3 ms** | 130× |
| `pr-xml-utf-8.xml`, 1 / 16 bytes, whole | 184 / 34 / 14 ms | 182 / 35 / 14 ms | unchanged |

`sampler2.exe` (no handlers), ms per parse ([timing-no-handlers.tsv](logs/timing-no-handlers.tsv)).

## 2. The problem

| Field | |
|---|---|
| **Environment** | Windows 11, student PC2; EiffelStudio 25.12, `msc_vc140`, MSVC (VS 18); `student-Mass` @ `270db12` |
| **Command** | `sampler2.exe text-<N>k.xml 2 stacks.txt 16` (no handlers set) |
| **Profile** | `parse_character_data_prefix` 76.5%, `is_resumable_text_run` 21.3% inclusive; both re-read the run from its start every call |
| **Cause** | ✔ Confirmed by the code: #11's text carry needs a character-data handler. Without one, the resume point is the start of the text token. The native `can_append_plain_ascii_text` shortcut, which makes 1-byte pieces fast, started only when the whole input was one plain start tag |

## 3. The change

- [x] **What Expat reports between calls was checked first** ([probe](logs/tools/posprobe.c), with Expat 2.8.1 compiled in, [results](logs/expat-positions/)). Inside a text run, Expat reports the end of all data fed so far, and XPact already matches it in 7- and 16-byte pieces. The shortcut reports `parser position + uncounted bytes`, which is the same, because plain ASCII has no line ends.
- [x] `{XP_PARSER}.ends_in_plain_text_run` (exported to `XP_NATIVE_PARSER`) is true when all of these hold:
  - the last prefix stopped in a text run inside an open element, outside any entity, without error;
  - the position is at the end of the input;
  - the bytes from the resume index to the end are plain ASCII (32 .. 126, no `<`, `&`, `]`).
- [x] `XP_NATIVE_PARSER` also sets `plain_ascii_text_prefix` in that case. It does so only when nothing is observable (no diagnostics, no native callbacks, not an external-entity parser, callbacks not deferred) and `has_one_byte_ascii_encoding` holds: no UTF-16; UTF-8, US-ASCII, ISO-8859-1 or nothing declared or explicit.
- [x] When other bytes arrive, the flag is cleared and the normal parse continues from the parser's saved state over all bytes, as with the existing start-tag case.

## 4. Verification

| Check | Result |
|---|---|
| ✅ Both tiers build | `System Recompiled.`, smoke `ok` |
| ✅ **No-handler check over 3,061 W3C files** (status, error code, final line / column / byte index, and a checksum of the position after **every** call), 1, 7, 16 bytes and whole | 0 differences from the previous build ([before / after](logs/no-handler-w3c/), [probe](logs/tools/nohprobe.c)). The first version of the change failed this for the two UTF-16 files byte by byte, which is why `has_one_byte_ascii_encoding` exists |
| ✅ Positions between calls against Expat (3 documents, 1 / 7 / 16 bytes) | unchanged from the previous build; 7 and 16 bytes match Expat exactly. Older 1-byte differences at the first bytes are untouched |
| ✅ DLL tests, 4,308 cases | 4,308 / 4,308 on both tiers; `results.tsv` byte-identical to `student-Mass` ([production](logs/dlltests-production-summary.txt), [assertions](logs/dlltests-assertions-summary.txt)) |
| ✅ W3C trace (with handlers: the shortcut stays off there) | 9 / 9 files byte-identical, both tiers ([production](logs/w3c-trace-sha256-production.txt), [assertions](logs/w3c-trace-sha256-assertions.txt)) |
| ✅ Test 2 (2,585 cases) | TSVs byte-identical to `student-Mass`, both tiers (`reports/issue-0165/tools/logs/chunked-fix53-*`) |
| ✅ Expat 2.8.1 `runtests` (many tests without handlers) | `Checks: 399, Failed: 38` on both tiers, the same 38 names ([production](logs/expat-runtests-production.txt), [assertions](logs/expat-runtests-assertions.txt)) |

## 5. How to revert

Revert the commit; the shortcut starts only after a lone start tag again.
