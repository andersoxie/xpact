import { lazy, Suspense } from "react";
import { BrowserRouter, Route, Routes } from "react-router-dom";
import { Layout } from "./components/Layout";
import { Home } from "./pages/Home";
import { NotFound } from "./pages/NotFound";

// The other pages load when they are first opened, so the home page downloads less script.
const Validator = lazy(() => import("./pages/Validator").then((m) => ({ default: m.Validator })));
const Docs = lazy(() => import("./pages/Docs").then((m) => ({ default: m.Docs })));
const Benchmarks = lazy(() => import("./pages/Benchmarks").then((m) => ({ default: m.Benchmarks })));
const Project = lazy(() => import("./pages/Project").then((m) => ({ default: m.Project })));

export function App() {
  return (
    <BrowserRouter>
      <Suspense fallback={<p className="muted">Loading …</p>}>
        <Routes>
          <Route element={<Layout />}>
            <Route index element={<Home />} />
            <Route path="validator" element={<Validator />} />
            <Route path="docs" element={<Docs />} />
            <Route path="benchmarks" element={<Benchmarks />} />
            <Route path="project" element={<Project />} />
            <Route path="*" element={<NotFound />} />
          </Route>
        </Routes>
      </Suspense>
    </BrowserRouter>
  );
}
