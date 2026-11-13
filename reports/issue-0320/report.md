# #320 · Text files outside `docs/` brought up to 2026-11-11

| | |
|---|---|
| Status | ✅ done (2026-11-11) |
| Issue | [#320](https://github.com/andersoxie/xpact/issues/320) |
| Scope | every tracked `.md` / `.txt` outside `docs/` and `website/docs/` (out of scope by request); evidence under `reports/issue-*` and `student/results/` not rewritten |

## What was stale and what changed

| File | Was | Now |
|---|---|---|
| `.github/pull_request_template.md` | PRs go into `student-Mass` | `incremental-test`, merge commit, never `main` |
| `student/README.md` | `fix.ps1 merge` squashes into `student-Mass`; branch table and "after merging" for `student-Mass` | merge commit into `incremental-test`; `student-Mass` deleted 2026-11-10 |
| `student/GUIDE.md` | step 2/6: branch from and squash into `student-Mass`; `fix.ps1` "broken in 5.1" | `incremental-test`, merge commit; 5.1 note as in README; banner: sections 6-7 are week 4 |
| `student/PLAN.md` | header 2026-11-10, "mass-xpact is a mirror" | 2026-11-11; mirror no longer in sync (`f37178d`, PR #93 there); tooling #318-#320 |
| `student/CONTINUE-HERE.md` | "expect 37/37" (42/42 in the table) | 42/42 (run below); #318/#319; `XPACT_FROZEN_DLL` in setup |
| `student/report/ActualReport.md`, `ActualReportShorter.md`, `setup-guide.md` | said PRs were squash-merged into `incremental-test` too | squash into `student-Mass` until 10 Nov, merge commits since |
| `CHANGELOG.md` (Unreleased) | missing #312, #314, #315, #316 | added, plus #318, #319 |
| `website/README.md` | status 20/20 tests, 2026-11-06 | 42/42, Docker image, #316, not online |
| `reports/README.md` | — | rows for #318, #319 with PR and commit |

Checked and left as they are: `README.md` (updated in #319), `VERSION` (0.9.0; nothing tagged since), `TODO_CODE_REVIEW.md` (status note 2026-11-11), `native/README.md`, `adapters/libexpat/README.md`, `examples/contributed/README.md`, `tools/compiler_assertions/README.md`, `verification/boogie/README.md`, `tests/dotnet/XpactDllTests/README.md` (their Jenkins mentions describe the supervisor's pipelines, which still exist), `website/guide.txt` (the original brief).

## Verification

| Check | Command | Result |
|---|---|---|
| Website test count quoted in CONTINUE-HERE and website/README | `powershell -File website\scripts\test.ps1` on `incremental-test` @ `af7eaf1` | ✅ 42 passed, 0 failed, frontend built, exit 0 ([log](test-website-2026-11-11.txt)) |
| Links added | `reports/issue-0286/report.md`, `reports/issue-0318/report.md`, `reports/issue-0319/report.md` exist | ✅ |
| No file under `docs/` changed | `git diff --name-only incremental-test -- docs website/docs` | ✅ empty |
