<div align="center">

# 🧭 Student guide: how to start on xpact

**For a new student joining the project.** Read this first; it tells you what to read next, in which order, and how to work.

![Start](https://img.shields.io/badge/start-here-8a2be2?style=for-the-badge)
![Branch](https://img.shields.io/badge/work_branch-incremental--test-1f6cc4?style=for-the-badge)
![Main](https://img.shields.io/badge/main-never_touch-c0302f?style=for-the-badge)

</div>

> **What:** a reading order and a way of working for xpact, an Eiffel XML parser that can replace libexpat.
> **Where:** `student/studentGuide.md` · live status: [CONTINUE-HERE.md](CONTINUE-HERE.md) · to-do: [open issues](https://github.com/andersoxie/xpact/issues)

---

## 1. The project in three sentences

1. **xpact** is an XML parser written in Eiffel. Through a small C bridge it offers the same C interface as [libexpat](https://github.com/libexpat/libexpat), so C programs can use it instead.
2. Eiffel's **contracts** (Design by Contract) check the parser's rules while it runs; that is the idea from [Finnian Reilly's article](https://www.eiffel.org/blog/Finnian%20Reilly/2026/05/finding-billion-user-project-eiffel-how-dbc-catches-security-flaws-rust-misses).
3. Your job is mostly **evidence**: build it, test it against the official W3C suite and libexpat, find and report problems, and fix what you are asked to fix.

## 2. Read in this order

| Step | Read | Why | Time |
|:---:|---|---|---|
| 1 | [docs/xpact-student-introduction.md](../docs/xpact-student-introduction.md) | the assignment, the ten-week plan, the words (chunks, assertions, ABI) | 1 h |
| 2 | [The article](https://www.eiffel.org/blog/Finnian%20Reilly/2026/05/finding-billion-user-project-eiffel-how-dbc-catches-security-flaws-rust-misses), then [docs/article-reading-guide.md](../docs/article-reading-guide.md) | why the project exists and how the repo maps to the article | 45 min |
| 3 | [student/GUIDE.md](GUIDE.md) | the whole project in plain words: builds, scripts, how to do one piece of work | 1 h |
| 4 | [student/CONTINUE-HERE.md](CONTINUE-HERE.md) | **the live state**: branches, what is done, what is next, setup on a new PC | 15 min |
| 5 | [student/HANDOVER.md](HANDOVER.md) | open work, known traps, review comments from the last student | 20 min |
| 6 | [docs/PROJECT-KNOWLEDGE.md](../docs/PROJECT-KNOWLEDGE.md) | the map of every doc; use it to look things up later, not to read it all | 10 min |
| 7 | [reports/four-way-2026-11-23/REPORT.md](../reports/four-way-2026-11-23/REPORT.md) | the latest full results: xpact vs libexpat vs Gobo vs Xpact-core | 20 min |
| 8 | [reports/four-way-2026-11-23/TEST-SUITES.md](../reports/four-way-2026-11-23/TEST-SUITES.md) | every test suite, what it proves and the command that runs it | 15 min |

**Later, when a task needs it:** the technical reading order in the main [README.md](../README.md#reading-order) (phase 1, test matrix, platform builds, design, libexpat API, incremental parsing).

## 3. Your first week

- [ ] **Day 1:** read steps 1–4 above. Install the tools in [CONTINUE-HERE.md §4](CONTINUE-HERE.md#4-setup-on-a-new-pc) and [TEST-SUITES.md §3](../reports/four-way-2026-11-23/TEST-SUITES.md#3-what-you-need-installed-once).
- [ ] **Day 2:** build once and run the quick checks: `.\scripts\build_native_eiffel.ps1`, then `.\scripts\run_dual_w3c.ps1` and `.\scripts\run_dual_regression.ps1`. Compare your numbers with the report.
- [ ] **Day 3:** run everything once: `.\benchmarks\four_way\run_four_way.ps1 -SkipLinux` (about 20 min). This is your **baseline**; keep its folder.
- [ ] **Day 4–5:** read steps 5–8, pick one open issue with your supervisor, and start on it the way §4 says.

## 4. How to work (every time)

| Rule | In practice |
|---|---|
| 🧱 **Baseline first** | run the tests **before** you change anything and save the result |
| 🎯 **One problem = one issue = one PR** | never mix fixes; write the expected result in the issue before testing |
| 🧾 **No "passed" without output** | link the log or summary that proves it; a cause is *confirmed*, *suspected* or *unknown* |
| 🌿 **Branches** | work on `incremental-test` or a branch from it; **never touch `main`**; merge commits only, never squash |
| 📁 **Evidence** | results go in `reports/issue-NNNN/`; never overwrite or delete old reports |
| 🤝 **Ask early** | design questions (assertion defaults, error columns, GC) go to the supervisor first |

## 5. Traps that cost time (found the hard way)

| Trap | What to do |
|---|---|
| Runners silently rebuild the DLL | note the SHA-256 the scripts print; reuse one build per change |
| PowerShell 5.1 turns tool stderr into errors | run steps through `cmd /c "powershell -File … > log 2>&1"`, as `run_four_way.ps1` does |
| `-Mode All` of the libexpat adapter only configures | run `-Mode NativeSuite` afterwards to run the tests |
| Native ABI tests need bash in the **default** WSL distro | `wsl --set-default Ubuntu-24.04` for the run, then set it back |
| The website shows 404 on every page | start the API from its own folder: `cd website\dist; .\Xpact.Api.exe` |
| Whole files of 10 MB+ fail in the native C ABI | known issue [#450](https://github.com/andersoxie/xpact/issues/450); use 5 MB for large-file tests |
| The Eiffel test matrix fails one doc check | known issue [#451](https://github.com/andersoxie/xpact/issues/451), not a parser bug |

## 6. Who to ask

| Who | About |
|---|---|
| [Anders Persson](https://www.linkedin.com/in/andersperssonbsharpab/) ([GitHub](https://github.com/andersoxie)), [Bsharp](https://bsharp.se/) | supervisor and repo owner: priorities, design, reviews |
| The previous student's notes | [student/report/ActualReport.md](report/ActualReport.md) and [student/notes/](notes/) |

**Check yourself:** after week 1 you should be able to say which branch you work on, how many W3C cases xpact passes, and which command reproduces that number. If you can, you are ready.
