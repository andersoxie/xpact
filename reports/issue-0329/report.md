# #329 · SonarQube issue 5: website React code smells (S6759, S6479, S3358, S6767)

| | |
|---|---|
| Status | ✅ fixed; rescan in [sonarqube-2026-11-12](../sonarqube-2026-11-12/README.md) |
| Issue | [#329](https://github.com/andersoxie/xpact/issues/329) |
| Files | `website/frontend/src/components/{Stat,BarChart,ResultPanel,XmlEditor,Layout}.tsx`, `pages/{Home,Project}.tsx` |

| Rule | Count | Fix |
|---|---|---|
| S6759 props not read-only | 8 | `Readonly<Props>` on `Stat`, `BarChart`, `ResultPanel`, `Count`, `LinkCard`, `MetricStat`, `Done`, `Todo` |
| S6479 array index as key | 3 | editor rows keyed by their line number, event rows by their place in the event stream (`seq`); both lists are rebuilt from scratch, never reordered |
| S3358 nested ternary | 2 | `Layout.tsx`: lookup tables `NEXT_THEME`, `THEME_LABEL` |
| S6767 unused prop | 1 | `readOnlyNote` removed from `XmlEditor` (no caller passed it) |

- **Cause:** ✅ confirmed by reading the code; no behaviour change intended.

## Verification

| Check | Result |
|---|---|
| `powershell -File website\scripts\test.ps1` | ✅ 42/42 backend tests, `tsc --noEmit` + `vite build` ok |
| Built site in headless Chromium (`vite preview`, no backend), covers #328 and #329 | ✅ header brand "XPact"; Home: 8 ticks, 8 "Done:" screen-reader texts, hidden (≤1 px); no `role="img"` left; theme button cycles ◐ Auto → ☀ Light → ☾ Dark → ◐ Auto; Validator: editor `section` with its label, gutter 1-2-3 for a 3-line document, labels "Parser build", "Feed the document"; screenshots look as before |
| Console | only the 4 expected `502` for `/api/*` (no backend behind the preview) |

Not checked at runtime: the bar chart and the result table (they need the API); both compile and keep their markup apart from the key and `Readonly` changes.
