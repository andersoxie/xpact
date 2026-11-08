# #211 recheck on `incremental-test` (2026-11-08)

| | |
|---|---|
| Code | andersoxie/xpact `incremental-test` @ `df75792` |
| Worker / DLL | `website/dist/Xpact.Worker.exe`, `website/dist/native/xpact.dll` (from `publish.ps1`) |
| Command | `python -I reports\issue-0211\laughs.py website\dist\Xpact.Worker.exe website\dist\native\xpact.dll reports\issue-0211\recheck-incremental-test` |

| Levels | Expands to | XPact before | **XPact now** | Expat |
|---|---|---|---|---|
| 3–5 | 10 KB – 1 MB | accepted | accepted (143–348 ms) | accepted |
| 6 | 10 MB | rejected after ~7 s, code 2 "syntax error" | **rejected, "amplification limit breached", 1.44 s** | rejected, amplification limit, 90 ms |
| 8 | 1 GB | rejected after ~7 s, "syntax error" | **rejected, "amplification limit breached", 1.47 s** | rejected, amplification limit, 81 ms |

**Result:** ✅ the error is now Expat's amplification-limit error (fixed by CodTanium/mass-xpact#60), and the time fell from ~7 s to ~1.4 s (includes ~0.15–0.3 s worker start; measured while other tests ran). 🟡 Still ~15× slower than Expat. In the libxml2 corpus, `recurse/lol_classic.xml` still gives "syntax error", and the external-entity variants `lol_eg.xml`/`lol_ep.xml` time out ([AlotOfTests 2026-11-08](../../../student/results/AlotOfTests-2026-11-08/README.md)).
