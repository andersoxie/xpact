import { useEffect, useState } from "react";
import { NavLink, Outlet } from "react-router-dom";
import { AUTHOR, LINKS } from "../data/site";

const NAV = [
  { to: "/", label: "Home", end: true },
  { to: "/validator", label: "Validator" },
  { to: "/docs", label: "Documentation" },
  { to: "/benchmarks", label: "Benchmarks" },
  { to: "/project", label: "Project" },
];

type Theme = "light" | "dark" | "system";

function useTheme(): [Theme, () => void] {
  const [theme, setTheme] = useState<Theme>(() => {
    try {
      return (localStorage.getItem("theme") as Theme) || "system";
    } catch {
      return "system";
    }
  });
  useEffect(() => {
    const root = document.documentElement;
    if (theme === "system") root.removeAttribute("data-theme");
    else root.setAttribute("data-theme", theme);
    try {
      localStorage.setItem("theme", theme);
    } catch {
      // Storage may be blocked; the theme still applies for this visit.
    }
  }, [theme]);
  const next = () => setTheme((t) => (t === "system" ? "light" : t === "light" ? "dark" : "system"));
  return [theme, next];
}

export function Layout() {
  const [theme, nextTheme] = useTheme();
  const themeLabel = theme === "system" ? "◐ Auto" : theme === "light" ? "☀ Light" : "☾ Dark";

  return (
    <>
      <header className="site-header">
        <div className="container">
          <NavLink to="/" className="brand" aria-label="XPact home">
            <img src="/favicon.svg" alt="" />
            XPact
          </NavLink>
          <nav className="nav" aria-label="Main">
            {NAV.map((item) => (
              <NavLink key={item.to} to={item.to} end={item.end}>
                {item.label}
              </NavLink>
            ))}
            <a href={LINKS.repo} target="_blank" rel="noreferrer">
              GitHub ↗
            </a>
          </nav>
          <button className="theme-toggle" onClick={nextTheme} title="Switch colour theme">
            {themeLabel}
          </button>
        </div>
      </header>
      <main>
        <div className="container">
          <Outlet />
        </div>
      </main>
      <footer className="site-footer">
        <div className="container footer-credit">
          <strong>Engine Development &amp; Quality Assurance</strong>
          <span>
            Core engine development, native integration, XML parsing, debugging, and extensive conformance testing by{" "}
            <a href={AUTHOR.github}>{AUTHOR.name}</a>.
          </span>
        </div>
        <div className="container">
          <span>
            <a href={LINKS.repo}>Source</a> · <a href={LINKS.issues}>Issues</a> ·{" "}
            <a href={LINKS.websiteDocs}>Website docs</a>
          </span>
        </div>
      </footer>
    </>
  );
}
