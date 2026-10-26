# Report: issue #106, finish the open week 2 and week 3 items in `student/PLAN.md`

Issue: [#106](https://github.com/andersoxie/xpact/issues/106)   Branch: `fix/106-week-2-3-items`   Base: `student-Mass` @ `7bb51c0`   Date: 2026-10-26

## In short

| | Item | Result |
|---|---|---|
| ✅ | Week 2: assertions DLL smoke test crashes (K3, draft 07) | ticked: fixed by #80, verified 2026-10-26 |
| ✅ | Week 2: 53 / 47 W3C crashes (draft 21) | ticked: fixed by #80, verified 2026-10-26 |
| ✅ | Week 2: "Report the baseline findings" | ticked: every sub-item is now ticked |
| ✅ | Week 3: #46 Jenkins stage turns red | ticked as **dropped** (#64), not as checked |
| ⏳ | Week 2: decision with the supervisor | **still open**: no decision recorded; needs the supervisor |
| ⏳ | Week 3: #35 six labels | **still open**: none exists on GitHub; creating them needs the supervisor's OK |
| ⏳ | Week 3: project board | **still open**: the student must run `gh auth refresh -s read:project,project` |

No code changed; the evidence comes from the #104 check of the same day.

## Evidence

| Item | Expected (from the drafts) | Actual, 2026-10-26 | Log |
|---|---|---|---|
| K3 | `.\scripts\build_native_eiffel.ps1 -BuildTier Assertions` builds the DLL and the smoke test passes | `Built ...\xpact_assertions.dll (Assertions)`, `xpact Eiffel DLL smoke: ok`, exit 0 | [03-dll-assertions.txt](../issue-0104/logs/03-dll-assertions.txt) |
| W3C crashes | every case ends in ACCEPT or REJECT; no contract violation | `FinalizedAssertions`: 1,727 passed, 0 failed, 0 errors; the word "crash" does not occur in the log | [12-benchmarks-w3c.txt](../issue-0104/logs/12-benchmarks-w3c.txt) |

Configuration: `student-Mass` @ `41731c8`, student PC, EiffelStudio 25.12.9.8922,
DLL built with MSVC (`msc_vc140`); W3C finalized with `-keep`, all assertions
on. The W3C result was repeated the same day with `ISE_C_COMPILER=msc_vc140`
for the Eiffel build: same numbers.

**Difference from the original finding:** draft 21 used
`scripts\run_xmlconf_conformance.ps1` with the workbench `xpact.exe`. That
script is no longer in the repository, so the check used the current runner,
`scripts/run_w3c_conformance.py`, through `run_benchmarks.ps1`.

## What was checked for the open items

| Item | Check | Result |
|---|---|---|
| Decision | `student/notes/weekly/week-02.md`, `week-03.md`, `student/for superviser.txt` | only "agree the main improvement with the supervisor"; no decision |
| #35 labels | `gh label list -R andersoxie/xpact --search <name>` for each of the 6 | none exists |
| Project board | `gh auth status` | scopes `gist`, `read:org`, `repo`; no `read:project` |

## Verification

| # | Command | Actual | |
|---|---|---|---|
| 1 | `git diff --stat origin/student-Mass` | `student/PLAN.md`, drafts 07 and 21 (4 lines added each), `reports/README.md`, this report | ✅ |
| 2 | unticked items in weeks 2-3 of `PLAN.md` | 3 left, each with the reason it cannot be finished by the student | ✅ |
| 3 | link check | 0 broken | ✅ |

## How to revert

```powershell
.\student\tools\fix.ps1 revert -Issue 106 -Commit <merged sha>
```
