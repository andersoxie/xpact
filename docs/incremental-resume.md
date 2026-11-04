# Incremental resume in the native parser

> **In short:** when a document arrives in several `XML_Parse` calls, the native
> parser now continues from where the previous call stopped. It no longer parses
> the whole buffer again on every call. Callbacks, positions and errors stay the same
> as before; only the time changes.

| | Before | Now |
|---|---|---|
| Cost of a document in *n* pieces | ≈ *n* × document size (square growth) | ≈ document size (linear) |
| 131 KB document, 16-byte pieces | 214.5 s | 0.16 s |
| When the fast path cannot be used | – | the old full replay, as before |

Issue: [CodTanium/mass-xpact#2](https://github.com/CodTanium/mass-xpact/issues/2).
Evidence and tools: [`reports/mass-xpact-issue-0002/`](../reports/mass-xpact-issue-0002/report.md).

## 1. How the old path works (still the fallback)

Every call appends its bytes to `input_buffer`, decodes the whole buffer, resets
the parser and parses everything from byte 1 (`XP_PARSER.parse_prefix`). Callbacks
the application already received are hidden by count:
`handler.prepare_callback_replay (delivered_callback_count)`. A text run split across
calls is one callback *index* whose delivered length grows
(`delivered_character_data_lengths`), so the replay delivers only the new suffix.

## 2. The resume path

After a successful non-final parse, `XP_PARSER` records a **checkpoint**:

| Field | Meaning |
|---|---|
| `resume_index` | where parsing continues in the normalized input |
| `resume_sequence_count` | the handler's callback count at that point |
| `resume_text_start` | the start of the text run, when the checkpoint is inside one |
| `resume_entity_bytes` | the entity accounting count (`expanded_entity_bytes`) at that point, so references in a text run that is parsed again are counted once |

The checkpoint is the first of:

1. the start of an unfinished markup token at the end of the input;
2. the start of a text run that reaches the end of the input (it is parsed again,
   and the delivered-length bookkeeping trims what was already sent);
3. the point after the last general entity reference of such a run (the text after
   a general reference is a new callback, so the reference is not expanded twice);
4. the end of the input.

On the next call, `XP_NATIVE_PARSER` gives the parser **only the bytes it has not
received** (`continue_prefix`). The parser is not reset: element stack, DTD tables,
namespaces and position counters carry on. New bytes are normalized and appended to
the same normalized buffer (`append_normalized_input`), so every position stays the
absolute position a full parse reports. The handler continues counting from the
checkpoint (`prepare_callback_resume`), so callback numbering stays exactly that of
a full replay.

Because the numbering is the same, the old full replay can take over at **any**
call. `input_buffer` is therefore still kept whole (memory use is unchanged).

## 3. When the old full replay is used

| Situation | Why |
|---|---|
| The first call, and any call after one that could not record a checkpoint | no checkpoint |
| An invalid character in the new bytes | the replay reports it exactly (#172 delivers the callbacks in front of it) |
| Input that is not plain UTF-8 or UTF-16 (Latin-1, ASCII, an explicit or unknown encoding), or an XML declaration that is not complete yet | decoding is still done on the whole buffer |
| UTF-16: an invalid surrogate, or a partial character at the final call | only the full decode reports it |
| External entity parsers, diagnostic events | not covered yet |
| An unfinished DOCTYPE that reports its parts as they arrive | no checkpoint inside a DOCTYPE |
| A text run seen by a default handler, or inside an entity, at the end of the input | the run is parsed again from its start (#11 carries the text only for the character data handler) |
| After a resumable stop (`XML_StopParser (p, XML_TRUE)`) | `XML_ResumeParser` replays, as before |
| The direct start-tag shortcut delivered a callback | the parser did not see that tag |

An error found by the resume path (including a non-resumable `XML_StopParser`) is
reported directly: the parser state is that of a full parse, so the error and its
position are the same.

### UTF-16 input ([mass-xpact#7](https://github.com/CodTanium/mass-xpact/issues/7))

The parser always reads UTF-8: `decoded_input` decodes UTF-16 before parsing. For
UTF-16 recognised by its signature (BOM or `<` shape, no explicit encoding), the native
parser keeps that decoding in `decoded_buffer`. Each later call decodes only the bytes
after `decoded_raw_count` (`append_decoded_utf16`, up to a character cut off by the end
of non-final input, as `complete_encoded_prefix_count` cuts it) and resumes the parser
on `decoded_buffer`. `resume_source` is the input a resumed parse reads: `input_buffer`
for UTF-8, `decoded_buffer` for UTF-16. Deferral, the pending-markup scan and
`resume_raw_count` work on it, exactly as the full replay works on its fresh decoding.
`XML_GetInputContext` still shows the raw `input_buffer`, as before.

### Long text runs ([mass-xpact#11](https://github.com/CodTanium/mass-xpact/issues/11))

A text run that reaches the end of non-final input used to be the checkpoint itself: the next
call parsed the whole run again, so a long paragraph fed in small pieces cost (run length)².
Now, when only the character data handler sees the run's text, the checkpoint is the point
where parsing stopped inside the run (`last_text_stop_index`) and the text so far is kept
(`resume_text_carry`). The next call continues there with that text as the seed
(`character_data_seed`). The run's callback is delivered again with the longer text, and the
handler passes on only the new suffix, as it does for a full replay.

- A trailing `]` or `]]` is parsed again, because the next byte may make it `]]>`.
- The carry is used only when no default handler wants the raw bytes, and in document content
  outside an entity (`can_carry_text_run`). Otherwise the run is parsed again from its start, as
  before. If the handlers change between calls so that the carry is no longer allowed,
  `continue_prefix` returns False and the full replay takes over.
- With reparse deferral on (Expat 2.6 default), `should_defer_reparse_callbacks_on_prefix` cuts a
  partial UTF-8 character off `input_buffer` for a moment. `pending_scan_index` is now clamped to
  the shorter buffer, so the scan for unfinished markup no longer restarts from byte 1.

## 4. Kept exactly as before

- **Reparse deferral** (Expat 2.6): the decision is made on the same bytes as the old
  path, without a UTF-8 character cut off by the end of non-final input
  (`should_defer_reparse_callbacks_on_prefix`).
- **`XML_GetInputContext`**: the context may now share `input_buffer`;
  `context_source_count` keeps its right edge where the old copy ended. Never call
  `context_source_buffer.wipe_out`: it could empty `input_buffer`.
- **Entity accounting** (indirect byte count of the billion-laughs protection): a resumed
  parse restarts the count from the checkpoint, so a predefined reference such as `&amp;`
  in a pending text run is not counted on every call (Expat's `test_accounting_precision`).
- **Scans for unfinished markup** continue where the previous scan stopped
  (`pending_markup_start`, `incomplete_markup_prefix_start_from`) instead of from byte 1.

## 5. Not done yet

- [x] ✅ Resume for UTF-16 input (#7): only the new bytes are decoded.
- [ ] Resume for Latin-1, ASCII, explicit and unknown encodings.
- [ ] Resume in external entity child parsers.
- [ ] Trim `input_buffer` once the fallback is no longer needed (memory).
- [x] ✅ Long text runs and deferral with a partial UTF-8 character (#11): no longer quadratic.
- [ ] Per-call overhead: byte-by-byte is still about 14× slower than one call.
