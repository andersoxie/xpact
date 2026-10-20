# Week 3 - 2026-10-19 to 2026-10-23 (written 2026-10-20)

## Tried
- Reported three failed runs ([error report](../../../reports/error-reports/2026-10-19.md)), then reran each in the git clone with exact commits and exit codes (#2, #3, #4, #7).
- Brought the week 1 build fixes into git, one issue and one tested pull request each: #2, #7, #10, plus #4 (PATH growth). Set up the versioning workflow (#5, `fix.ps1`) and one report folder per fix (#14): [reports/README.md](../../../reports/README.md).
- Investigated B03 (#3) by letting the swallowed exception through in a throwaway worktree.

## What the evidence shows
- The native DLL, the assertions DLL (`-SkipSmoke`) and the native runtime smoke test now build in a fresh shell (#7, #10). The cause was the default mingw C backend; `msc_vc140` fixes it.
- Repeated MSVC imports grew PATH by 1,432 characters each; the 5th failed. Now PATH stays at 2,657 (#4).
- **B03: the contract is wrong, not the code or the test.** The loop variant in `direct_start_tag_attributes` does not decrease at the `/` of `<root/>`. `MEMORY.execute_without_collection` swallowed that exception, so only `final_finished_or_suspended` showed (fix and report in pull request [#12](https://github.com/andersoxie/xpact/pull/12)). With the fix, all four matrix cells pass.
- New finding: GC-suspended parses silently drop exceptions (#13).

## Blocked
- #12 (parser change) waits for review by the parser's developer.
- The build fixes are on `student-Mass`, not `main` (draft 22): ask the supervisor.

## Next week
- A02: rerun the baseline in the git clone. B01/B02: nonzero exit on failure and meta-tests. Bring in `run_xmlconf_conformance.ps1` and patch 02.
