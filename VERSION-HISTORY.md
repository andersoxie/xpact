# XPact versions: the easy list

**What:** every XPact version in short, plain words: what was **added**, **changed** or **removed**.
**Where:** `VERSION-HISTORY.md` on `main`. Full detail per version: [CHANGELOG.md](CHANGELOG.md). The version now: [VERSION](VERSION).

**Live website:** https://xpact.bsharp.se/ · Jenkins deploys the Docker image named in `ci/Jenkinsfile.website-deploy`.

---

## ▶ 0.10.1 · 2026-11-26 · website only

- ➕ **Added:** the Google Search Console meta tag on the home page, so Google can verify that we own the site.
- 🔁 **Changed:** the live site uses image `website-2026-11-26-1` (before: `website-2026-11-14-3`).
- ➖ **Removed:** nothing.
- ✅ **Checked:** the new build differs from the old one in only 2 files: the home page (the tag) and the build note. A local run worked (health, home page, parsing).
- ↩ **Undo:** revert the merge commit on `main` (`git revert -m 1 <merge>`), or deploy `website-2026-11-14-3` again in Jenkins.

## 0.10.0 · 2026-11-19 · milestone

- ➕ The DLL is safe from several threads, and a Gobo DLL exists.
- 🔁 The parser is 1.07× faster, SonarQube reports 0 issues, and there is one live status page.

## 0.9.0 · 2026-11-10 · launch candidate

- ➕ Website hardening tests and .NET tests in Jenkins.
- 🔁 `main` = `incremental-test`.

## 0.8.0 · 2026-11-09

- ➕ Boogie proofs of two parser loops.
- 🔁 `main`'s Gobo benchmark work is merged in.

## 0.7.0 · 2026-11-09

- 🔁 The final parser is fully retested.
- ➕ A website release and a Docker image.

## 0.6.0 · 2026-11-05

- 🔁 Speed work: incremental parsing; the final parser source.

## 0.5.0 · 2026-11-02

- ➕ The XPact website and the 11-area test campaign.

## 0.4.0 · 2026-10-31

- 🔁 The output matches Expat on the W3C cases.

## 0.3.0 · 2026-10-28

- ➕ All 2,585 W3C cases run.
- 🔁 7 parser bugs fixed.

## 0.2.0 · 2026-10-23

- 🔁 Build and test-runner fixes; the first student merge into `main`.

## 0.1.0 · 2026-10-14 · start

- ➕ Baseline: the supervisor's XPact and the W3C benchmark runner.

---

**Rule for new versions:** add one block at the top, using the same 5 lines (Added, Changed, Removed, Checked, Undo).
