import { BrowserRouter, Route, Routes } from "react-router-dom";
import { Layout } from "./components/Layout";
import { Benchmarks } from "./pages/Benchmarks";
import { Docs } from "./pages/Docs";
import { Home } from "./pages/Home";
import { NotFound } from "./pages/NotFound";
import { Project } from "./pages/Project";
import { Validator } from "./pages/Validator";

export function App() {
  return (
    <BrowserRouter>
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
    </BrowserRouter>
  );
}
