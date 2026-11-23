import { useEffect, useRef, useState } from "react";
// Rendered from reports/four-way-2026-11-23/*.md by website/scripts/export-report.ps1 with GitHub's own
// Markdown renderer (which sanitises the HTML). Bundled at build time: nothing is fetched at run time.
import reportHtml from "../data/reports/REPORT.html?raw";
import suitesHtml from "../data/reports/TEST-SUITES.html?raw";
import "../styles/github-markdown.css";
import "../styles/report.css";

const TABS = [
  { id: "report", label: "Four-way comparison", file: "REPORT.md", html: reportHtml },
  { id: "suites", label: "Test suites (reproduce)", file: "TEST-SUITES.md", html: suitesHtml },
] as const;
type TabId = (typeof TABS)[number]["id"];

/** Colour class for a result cell, from the symbols it contains (✅ passed, ❌ failed, 🚫 no result). */
function resultClass(text: string): string {
  const good = text.includes("✅");
  const bad = text.includes("❌");
  if (good && bad) return "r-warn";
  if (bad) return "r-bad";
  if (text.includes("\u{1F6AB}")) return "r-none";
  if (good) return "r-good";
  return "";
}

export function Comparison() {
  const [tab, setTab] = useState<TabId>("report");
  const body = useRef<HTMLElement>(null);
  const current = TABS.find((t) => t.id === tab) ?? TABS[0];

  useEffect(() => {
    const root = body.current;
    if (!root) return;
    root.querySelectorAll("td").forEach((td) => {
      const cls = resultClass(td.textContent ?? "");
      if (cls) td.classList.add(cls);
    });
    root.querySelectorAll<HTMLAnchorElement>('a[href^="http"]').forEach((a) => {
      a.target = "_blank";
      a.rel = "noreferrer";
    });
    // in-page links (#1-summary): scroll inside the page instead of changing the route (links also fire click on Enter)
    const onClick = (event: MouseEvent) => {
      const href = (event.target as HTMLElement).closest("a")?.getAttribute("href");
      if (!href?.startsWith("#")) return;
      event.preventDefault();
      document.getElementById(decodeURIComponent(href.slice(1)))?.scrollIntoView({ behavior: "smooth" });
    };
    root.addEventListener("click", onClick);
    // sections fade in as they scroll into view
    const blocks = Array.from(root.children).filter((el) => el.tagName !== "H1");
    if (!("IntersectionObserver" in globalThis)) return () => root.removeEventListener("click", onClick);
    const seen = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting) {
            e.target.classList.add("in");
            seen.unobserve(e.target);
          }
        }
      },
      { rootMargin: "0px 0px -40px 0px" },
    );
    for (const el of blocks) {
      el.classList.add("reveal");
      seen.observe(el);
    }
    // never leave content hidden (no scrolling, screenshots, printing): show everything after a moment
    const fallback = setTimeout(() => {
      for (const el of blocks) el.classList.add("in");
    }, 1200);
    return () => {
      clearTimeout(fallback);
      root.removeEventListener("click", onClick);
      seen.disconnect();
    };
  }, [tab]);

  return (
    <div className="report-page">
      <div className="report-tabs" role="tablist" aria-label="Report documents">
        {TABS.map((t) => (
          <button key={t.id} role="tab" aria-selected={t.id === tab} onClick={() => setTab(t.id)}>
            {t.label}
          </button>
        ))}
      </div>
      <div className="report-file">{current.file} · rendered by GitHub's Markdown API</div>
      <article
        key={current.id}
        ref={body}
        className="markdown-body"
        // Trusted, build-time content from this repository, sanitised by GitHub's renderer (see the imports).
        dangerouslySetInnerHTML={{ __html: current.html }}
      />
    </div>
  );
}
