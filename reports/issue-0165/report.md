# Report: issue #165: callbacks delivered twice when the input arrives in pieces

> **Issue:** [#165](https://github.com/andersoxie/xpact/issues/165) F02-1 · found by test 2 of the extra test round (W3C fed in pieces)
> **Branch:** `fix/165-delivered-callbacks-never-decrease`, from `student-Mass` @ `e5d59e2` (= `main` @ `2488f44`) · **Changed:** `src/xp_native_parser.e` (1 line + comment)
> **Status:** ✅ fixed · ✅ verified locally, both builds, including Expat's own C tests · 🟡 waiting for a Jenkins run before the issue is closed

## 1. In short

Test 2 feeds all 2,585 W3C documents to `xpact.dll` whole, byte by byte and split in two at every position (≤ 4 KB), and compares verdict, error code and events with the whole-document parse; Expat is the control.

| Test 2 | Before (`e5d59e2`) | After |
|---|---:|---:|
| ✅ the same verdict, error code and events in every mode | 1,995 | **2,438** |
| 🔴 xpact only: other events or error code | 585 | **142** |
| ⚪ Expat changes as well | 5 | 5 |
| ❌ documents that got **worse** | | **0** |
| ✅ the **verdict** changes | 0 | 0 |

**443 documents became stable.** F02-1 (duplicate `startdoctype`) is gone completely; the 139 event differences left are all F02-2 (whole document: no events before an error), a separate problem. Assertions and normal build give the same result per case.

## 2. Problem report (CLAUDE.md format)

| Field | |
|---|---|
| **1. Problem** | When a document arrives in several `XML_Parse` calls, callbacks the application already received (`startdoctype`, `entitydecl`, …) are delivered again |
| **2. Environment** | Windows 11 (student PC); EiffelStudio 25.12, MSVC (`msc_vc140`); Python 3.14; Expat control `pyexpat` 2.7.3; Expat 2.8.1 source for `runtests`; both DLL builds |
| **3. Command** | `python -I reports\issue-0165\chunk_probe.py <dll>`; test 2: `python -I reports\issue-0165\tools\run.py --dll <dll> --tag <name>` then `analyze.py <name>` |
| **4. Expected** | `xmldecl, startdoctype, entitydecl, enddoctype, start, end`, each once (whole, and Expat in every mode) |
| **5. Actual (before)** | 4 pieces `<?xml version="1.0"?` · `><!DOCTYPE d [<!ENTITY e "v">` · `]` · `><d/>`: call 2 delivers `xmldecl, startdoctype, entitydecl`, call 3 nothing, call 4 `startdoctype, entitydecl` **again** ([before](logs/checks/chunk-probe-before.txt)) |
| **6. Error output** | none; the document is accepted |
| **7. Investigation** | The smallest pattern was found by starting from byte by byte and merging pieces while the duplicate stayed: 4 pieces (2 or 3 pieces never trigger it). The DLL re-parses the whole buffer on every call and skips what was delivered (`handler.prepare_callback_replay (delivered_callback_count)`). After a non-final call it set `delivered_callback_count := handler.callback_sequence_count`. Call 3 re-parses only up to the unfinished DOCTYPE (1 callback), so the count fell from 3 to 1 although the application had received 3; call 4 then repeated callbacks 2 and 3 |
| **8. Cause** | ✅ **confirmed**: keeping the count from going down removes every duplicate (443 documents) and changes nothing else (section 4) |
| **9. Fix** | `src/xp_native_parser.e`: `delivered_callback_count := delivered_callback_count.max (handler.callback_sequence_count)`; delivered callbacks stay delivered |
| **10. Verification** | ✅ section 4 |

## 3. The change

```eiffel
else
		-- A call may re-parse less than an earlier one (for example only up to an
		-- unfinished DOCTYPE); the callbacks the application already received stay delivered.
	delivered_callback_count := delivered_callback_count.max (handler.callback_sequence_count)
end
```

## 4. Verification

Assertions build first, then the normal build, on `e5d59e2` + #165.

| Check | Before | After the fix | Log |
|---|---|---|---|
| ✅ DLL build + smoke test | ok ×2 | ok ×2 | [assertions](logs/checks/build-assertions.txt), [normal](logs/checks/build-normal.txt) |
| ✅ Chunk probe (whole, 4 pieces, byte by byte) | 1 / 3 | **3 / 3** | [before](logs/checks/chunk-probe-before.txt), [after](logs/checks/chunk-probe-after.txt) |
| ✅ **Test 2, W3C in pieces** (both builds) | 1,995 stable | **2,438** stable, 0 worse; normal = assertions | [before](logs/test2/chunked-e5d59e2-assertions-summary.json), [after](logs/test2/chunked-fix165-assertions-summary.json), [what still differs](logs/test2/unstable-fix165-assertions.tsv) |
| ✅ W3C output test | 399 / 432 | **399 / 432**, both builds | [assertions](logs/after-assertions/results.tsv), [normal](logs/after-normal/results.tsv) |
| ✅ Expat's C tests (`runtests`) | 38 fails (allocator) | **the same 38** | [before](logs/checks/runtests-before-fails.txt), [after](logs/checks/runtests-after-fails.txt) |
| ✅ W3C verdicts through the DLL, all 2,585 | baseline | **identical** per case, both builds | [summaries](logs/checks/verdicts/) |
| ✅ Jenkins Benchmarks stage, run locally (`-SkipWslC`) | 2,283 + 302, 0 failed | **2,283 + 302, 0 failed, 0 errors, 0 skipped**, both builds | [summary](logs/checks/jenkins-w3c/summary.md) |
| ✅ External entities through the DLL | 247 / 247 | **247 / 247** | [summary](logs/checks/dll-entity-lane/summary.json) |
| ✅ Python suite | 206 OK | **206 OK** | [log](logs/checks/python.txt) |
| ✅ C# DLL tests vs Expat 2.8.1 (4,308 inputs) | recorded table | **identical**, both builds | [off](logs/checks/csharp/xpact/), [on](logs/checks/csharp/xpact_assertions/) |
| ✅ Dual regression lane (xpact) | 910 / 910 | **910 / 910**, both builds | [summary](logs/checks/dual-regression/summary.md) |
| ✅ Eiffel test matrix | 4 / 4 | **4 / 4** | [log](logs/checks/eiffel-matrix.txt) |
| 🟡 Jenkins | | not run yet | |

The before numbers of test 2 were measured again on `e5d59e2` (both builds) and are identical, case by case, to the first run on `293918f` (2026-10-28).

## 5. Problems met (kept separate)

| Problem | Cause | What was done |
|---|---|---|
| Test 2 takes about 25 minutes per build | ✅ by design of the DLL: every call re-parses the whole buffer (F05-1), so byte by byte reads about n²/2 bytes (172 billion for the suite) | noted; a fix for F05-1 needs the supervisor's decision |
| Dual lane: `xpact-core` not built | ✅ environment (no cached Xpact-core in this worktree) | xpact lane only |

## 6. Limitations

- Only the main document is fed in pieces; external entities are read whole.
- The 139 remaining differences (F02-2) and the one error-code difference (F02-3) are not touched here.

## 7. Revert

After the squash merge: `.\student\tools\fix.ps1 revert -Issue 165 -Commit <merged sha>`.
