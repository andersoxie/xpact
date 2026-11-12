# #328 · SonarQube issue 4: website accessibility (S6819, S6848, S6772)

| | |
|---|---|
| Status | ✅ fixed; rescan and page check in [sonarqube-2026-11-12](../sonarqube-2026-11-12/README.md) |
| Issue | [#328](https://github.com/andersoxie/xpact/issues/328) |
| Files | `website/frontend/src/pages/Home.tsx`, `Validator.tsx`, `components/BarChart.tsx`, `XmlEditor.tsx`, `Layout.tsx`, `styles/app.css` |

| Rule | Where | Problem | Fix |
|---|---|---|---|
| S6819 | `Home.tsx` `Done` / `Todo` | emoji in `<span role="img" aria-label>` | emoji `aria-hidden`, plus screen-reader text "Done: " / "To do: " (`.sr-only`) |
| S6819 | `BarChart.tsx` | `<div role="img" aria-label={caption}>` hid the readable bar labels and values from screen readers | plain `<div>`; the caption becomes a real `<figcaption>` (screen-reader only, no visual change) |
| S6848 | `XmlEditor.tsx` | drag-and-drop handlers on a plain `<div>` | `<section aria-label="XML editor: …">`; keyboard users still have the textarea and the file button |
| S6772 | `Layout.tsx`, `Validator.tsx` (3×) | text next to an element across a line break (whitespace unclear) | text wrapped in `<span>`; the parents are flex containers, so the layout is the same |

- **Cause:** ✅ confirmed by reading the code.
- `.sr-only` is the usual visually-hidden pattern (1×1 px, clipped).

## Verification

| Command | Result |
|---|---|
| `powershell -File website\scripts\test.ps1` | ✅ 42/42 backend tests; `tsc --noEmit` + `vite build` ok; "All website checks passed." |
| No test or CSS selector used the removed `role="img"` / `div.editor` | ✅ `git grep` |
