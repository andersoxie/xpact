# Shared adapter contract: DRAFT

> **Status: draft for review (step 3 of the dual-implementation plan).** Written
> by the student on 26 October 2026 from what the existing lanes already do
> ([catalog](dual-catalog-lane.md), [W3C](dual-w3c-lane.md),
> [regression](dual-regression-lane.md)), the C# DLL tests
> (`tests/dotnet/XpactDllTests`) and the Expat 2.8.1 comparison (#121).
> Rows marked **open** need a decision.

**Reviewed against the current repository, 13 November 2026.** This remains a
proposal, not an approved common API or a current issue-status list. The three
direct Eiffel lanes are implemented; native core DLL/.NET integration is not.
Dated runtime observations below retain their original compiler and pinned-core
scope. The W3C resource policy and finalized-assertion statement are updated here.

The contract says what every backend adapter must do, so that one set of
fixtures and expectations can run on xpact, Xpact-core and, later, their DLLs.

## 1. Input

| # | Rule | Today |
|---|---|---|
| I1 | The adapter receives the **original bytes**. No caller-side decoding, transcoding, BOM removal or newline change | all three lanes |
| I2 | The parser detects the encoding itself (BOM, declaration) | W3C lane |
| I3 | Input arrives as a **sequence of chunks**; only the last is final. The same bytes must give the same verdict and events for every division | regression lane, C# tests |
| I4 | Required divisions: whole; split at every byte; one byte per call **followed by an empty final call**; one byte per call with the last one final | regression lane. **Open:** Xpact-core rejects the empty final call (14 runs) and a lone-CR chunk (8 runs). Expat accepts both |
| I5 | The caller may release or reuse a chunk once `parse` returns. An adapter whose parser shares chunk memory must keep it alive itself | Xpact-core adapter keeps every codec until the run ends |

## 2. Options

| # | Option | Today |
|---|---|---|
| O1 | Namespaces on or off, with the separator, fixed at construction | W3C lane (`|`) |
| O2 | External-resource policy is explicit and confined to the supplied suite root | Current W3C lane enables suite-local external general/parameter entities for xpact; pinned core has no loader. This is a recorded capability difference, not equivalent resource behavior |
| O3 | **Open:** specify shared event/lifecycle obligations for DTD default attributes, the default handler, suspension and resume | W3C binary verdict coverage does not by itself establish these event/API contracts |

## 3. Lifecycle and ownership

| # | Rule | Today |
|---|---|---|
| L1 | `create`, then any number of runs (`reset`, `parse`…), then `close` | all lanes |
| L2 | `reset` returns the parser to its initial state after **success, failure or partial input** | regression lifecycle: 10/10 steps for both parsers |
| L3 | `close` releases the parser, input buffers and handler references; a closed adapter reports itself closed | catalog and W3C `is_closed` |
| L4 | The caller's GC state is the same after a run as before it, whatever the backend does internally | catalog and W3C `restore_gc`; core switches GC off and does a full collect on final input |
| L5 | **Open:** extend resource-release checks to native handles, child processes and allocator behavior | Catalog/W3C controls check owned parser/input references on close; they do not measure allocator leaks or qualify a core native DLL |

## 4. Output

| # | Rule | Today |
|---|---|---|
| R1 | Verdict: ACCEPT only when the final call succeeds **and** no error is recorded | all lanes |
| R2 | On REJECT: a status, an **error code that is not "none"**, and a description | regression lane. Xpact-core breaks this for a lone-CR chunk (`Status_error`, code 0) |
| R3 | Events: element start (name), element end (name), character data, in document order; whitespace preserved | regression lane |
| R4 | Allowed difference: how character data is divided between calls (joined before comparing) | regression lane, C# tests |
| R5 | **Open:** error codes and positions. xpact and Expat differ (#122, #124); Xpact-core has its own codes. Compare them, but judge only the verdict until a profile is agreed | C# tests vs Expat |
| R6 | **Open:** the default handler's text. Expat passes the raw bytes; xpact passes normalized line ends (#126) | |

## 5. Results and failures

| # | Rule | Today |
|---|---|---|
| F1 | Every case has a result for every selected backend: PASS, WRONG-VERDICT, WRONG-EVENTS, CRASH, TIMEOUT, MISSING or excluded with a reason. Nothing is silently dropped | regression and W3C lanes |
| F2 | A crash or timeout is isolated to the smallest unit (case, then chunking) and never counted as a pass | regression lane, C# tests |
| F3 | One backend's build failure does not hide the other's results | regression lane |
| F4 | Expectations are written **independently of both parsers**; agreement alone is not a pass | all lanes |
| F5 | Every result names the backend's implementation, revision, configuration and GC policy | identity lines of all lanes |

## 6. Builds and assertions

| # | Rule | Today |
|---|---|---|
| B1 | Each backend builds in its own directory from a pinned revision; build inputs are fingerprinted, and a change during the build fails the run | `build_implementations.py` (observed on 26 October: an edit during a run correctly failed it) |
| B2 | Requested assertion flags need execution probes; finalization alone does not imply loop checks are absent | Both regression ECF assertion targets request `loop="true"`. The 26 October #40 mutation was missed in that generated build. Separate finalized EiffelStudio 25.02 and Gobo 26.11.12 probes detect loop invariants and variants; see [bounded qualification](gobo-assertions.md). This does not rerun or explain the older mutation |

## 7. Questions for the supervisor

1. Should the empty final call (I4) be a required division? Expat callers use it, and Xpact-core fails it today.
2. Error codes and positions (R5): which reference, Expat 2.8.1 or the XML spec only?
3. The default handler (R6): raw bytes as in Expat, or normalized?
4. Should the regression lane's cases move into a shared fixture folder that the Eiffel suite also reads (step 5)?
