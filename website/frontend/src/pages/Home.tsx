import { Link } from "react-router-dom";
import { getConformance, getComparison, getTesting } from "../api/client";
import type { Metric } from "../api/types";
import { useFetch } from "../api/useFetch";
import { Stat } from "../components/Stat";
import { LINKS } from "../data/site";

const fmt = new Intl.NumberFormat("en");

export function Home() {
  const conformance = useFetch(getConformance);
  const comparison = useFetch(getComparison);
  const testing = useFetch(getTesting);
  const prod = conformance.data?.builds.find((b) => b.build === "production");

  return (
    <>
      <section className="hero">
        <span className="badge">Work in progress · student project</span>
        <h1 style={{ marginTop: 14 }}>XPact: an XML parser you can check</h1>
        <p className="lead">
          XPact is an XML parser written in <strong>Eiffel</strong>, with a C library that offers the same API as{" "}
          <a href={LINKS.expat}>Expat</a>, the widely used C parser. Every part of the parser carries contracts
          (preconditions, postconditions and invariants), and a special build checks them on every document.
        </p>
        <div className="hero-actions">
          <Link to="/validator" className="btn btn-primary">
            Try it on your XML ▸
          </Link>
          <Link to="/docs" className="btn">
            Read the documentation
          </Link>
          <a href={LINKS.repo} className="btn">
            Source on GitHub ↗
          </a>
        </div>
      </section>

      <section className="section grid grid-4">
        <Stat
          label="W3C test cases"
          value={prod ? fmt.format(prod.total) : "…"}
          sub={prod ? `${prod.failed + prod.errors} failed, ${prod.skipped} skipped` : "loading"}
        />
        <Stat
          label="Verdict checked against W3C"
          value={prod ? fmt.format(prod.passed) : "…"}
          sub={prod ? `+ ${fmt.format(prod.noCrashOnly)} where either verdict is allowed` : ""}
        />
        <Stat
          label="Same verdict as Expat"
          value={comparison.data?.sameVerdict ? `${fmt.format(comparison.data.sameVerdict)} / ${fmt.format(comparison.data.pairs ?? 0)}` : "…"}
          sub="document × chunking pairs"
        />
        <Stat label="Builds" value="2" sub="production · assertions checked" />
      </section>

      {testing.data && (
        <>
          <section className="section">
            <h2>Tested hard</h2>
            <p className="muted">
              Eleven test areas, from the W3C suite to fuzzing, security attacks and real-world corpora, each compared
              with Expat. {testing.data.note}{" "}
              <a href={testing.data.source}>Evidence and sources ↗</a>
            </p>
            <div className="grid grid-4">
              {testing.data.testing.map((m) => (
                <MetricStat key={m.label} metric={m} />
              ))}
            </div>
          </section>

          <section className="section">
            <h2>Results against Expat</h2>
            <p className="muted">
              The same inputs through XPact and Expat, the reference parser, compared case by case.{" "}
              <a href={testing.data.source}>Per-test details ↗</a>
            </p>
            <div className="grid grid-4">
              {testing.data.results.map((m) => (
                <MetricStat key={m.label} metric={m} />
              ))}
            </div>
          </section>

          <section className="section">
            <h2>The project in numbers</h2>
            <p className="muted">
              {testing.data.project.period}. {testing.data.project.note}
            </p>
            <div className="grid grid-4">
              {testing.data.project.items.map((m) => (
                <MetricStat key={m.label} metric={m} />
              ))}
            </div>
          </section>
        </>
      )}

      <section className="section grid grid-3">
        <div className="card">
          <h3>What is XPact?</h3>
          <p className="muted">
            A non-validating XML 1.0 (5th edition) parser. It reads a document and reports what it finds as events
            (start tag, text, end tag …), or stops at the first error with a code, a line and a column.
          </p>
        </div>
        <div className="card">
          <h3>What problem does it solve?</h3>
          <p className="muted">
            Parsers read untrusted input, so their bugs matter. XPact is built so its correctness can be checked: by
            contracts inside the code, by the W3C conformance suite, and by comparing every result with Expat.
          </p>
        </div>
        <div className="card">
          <h3>How does it relate to Expat?</h3>
          <p className="muted">
            <code>xpact.dll</code> exports the Expat C API (<code>XML_ParserCreate</code>, <code>XML_Parse</code>, the
            handler setters …), so a program written for Expat can use XPact. Its behaviour is measured against Expat
            2.8.1.
          </p>
        </div>
      </section>

      <section className="section grid grid-2">
        <div className="card">
          <h2>Current status</h2>
          <ul className="check-list">
            <Done>Builds on Windows: Eiffel parser, native DLL, assertions build</Done>
            <Done>W3C XML conformance suite: all 2,585 cases run, 0 failed in both builds</Done>
            <Done>External entities through the C API: 247 / 247</Done>
            <Done>Same accept/reject verdict as Expat in every compared case</Done>
            <Todo>Error codes and events identical to Expat in every case (most match; see the open issues)</Todo>
            <Todo>Fast incremental parsing through the DLL (small pieces are slow today)</Todo>
          </ul>
          <p className="small muted" style={{ marginTop: 10 }}>
            Details and evidence: <Link to="/benchmarks">Benchmarks and conformance</Link> ·{" "}
            <a href={LINKS.plan}>project plan</a>
          </p>
        </div>
        <div className="card">
          <h2>Try XPact in three steps</h2>
          <ol className="muted" style={{ paddingLeft: 20, marginBottom: 16 }}>
            <li>Open the validator.</li>
            <li>Paste XML or drop a file.</li>
            <li>Press Validate: see accepted or rejected, the error position and the parser events.</li>
          </ol>
          <Link to="/validator" className="btn btn-primary">
            Open the validator ▸
          </Link>
        </div>
      </section>
    </>
  );
}

function MetricStat({ metric }: { metric: Metric }) {
  const number = typeof metric.value === "number" ? fmt.format(metric.value) : metric.value;
  const value = metric.approx ? `≈ ${number}` : number;
  return <Stat label={`${metric.icon} ${metric.label}`} value={value} sub={metric.sub} long={value.length > 11} />;
}

function Done({ children }: { children: React.ReactNode }) {
  return (
    <li>
      <span className="tick" aria-label="done">
        ✅
      </span>
      <span>{children}</span>
    </li>
  );
}

function Todo({ children }: { children: React.ReactNode }) {
  return (
    <li>
      <span className="todo" aria-label="to do">
        ⬜
      </span>
      <span>{children}</span>
    </li>
  );
}
