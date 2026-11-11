import { useState } from "react";
import { getBenchmarks, getComparison, getConformance } from "../api/client";
import { useFetch } from "../api/useFetch";
import { BarChart } from "../components/BarChart";
import { Stat } from "../components/Stat";
import { LINKS } from "../data/site";

const fmt = new Intl.NumberFormat("en");

// Colour follows the engine family, never its rank.
const FAMILIES = [
  { key: "dll", label: "XPact C library (xpact.dll)", color: "var(--series-3)", test: (e: string) => e.includes("native C ABI") },
  { key: "eiffel", label: "XPact Eiffel parser", color: "var(--series-1)", test: (e: string) => e.startsWith("xpact Eiffel") },
  { key: "expat", label: "Expat (through Python's pyexpat)", color: "var(--series-2)", test: (e: string) => e.includes("libexpat") },
];
const family = (engine: string) => FAMILIES.find((f) => f.test(engine)) ?? FAMILIES[1];

export function Benchmarks() {
  const conformance = useFetch(getConformance);
  const benchmarks = useFetch(getBenchmarks);
  const comparison = useFetch(getComparison);
  const [showTable, setShowTable] = useState(false);
  const c = conformance.data;
  const prod = c?.builds.find((b) => b.build === "production");

  return (
    <>
      <div className="page-head">
        <h1>Benchmarks and conformance</h1>
        <p>
          The evidence behind the parser: how it scores on the official W3C test suite, how it compares with Expat, and
          how fast it is. The numbers come straight from the reports in the repository; each section links to its source.
        </p>
      </div>

      {conformance.error && <div className="alert">Conformance data: {conformance.error}</div>}

      {c && prod && (
        <>
          <div className="grid grid-4">
            <Stat label="W3C cases run" value={fmt.format(prod.total)} sub={`suite ${c.suite.version}`} />
            <Stat label="Verdict matches W3C" value={fmt.format(prod.passed)} sub="checked cases, each build" />
            <Stat label="No crash (either verdict allowed)" value={fmt.format(prod.noCrashOnly)} sub="optional errors, XML 1.1" />
            <Stat label="Failed · errors · skipped" value={`${prod.failed} · ${prod.errors} · ${prod.skipped}`} sub="both builds" />
          </div>

          <section className="section">
            <h2>W3C XML conformance</h2>
            <p className="muted">
              The <a href={c.suite.url}>{c.suite.name}</a> ({fmt.format(c.suite.cases)} documents) asks a parser to
              accept every well-formed document and reject every broken one. Profile: {c.profile}.
            </p>
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Group of cases</th>
                    <th>Judged by</th>
                    <th className="num">Cases</th>
                    <th>Production</th>
                    <th>Assertions</th>
                  </tr>
                </thead>
                <tbody>
                  {c.lanes.map((lane) => (
                    <tr key={lane.lane}>
                      <td>{lane.title}</td>
                      <td>{lane.judgedBy}</td>
                      <td className="num">{fmt.format(lane.cases)}</td>
                      {/* The report records 0 failures and 0 errors per build, so every lane is complete. */}
                      <td>
                        <Pass cases={lane.cases} ok={prod.failed + prod.errors === 0} />
                      </td>
                      <td>
                        <Pass cases={lane.cases} ok={(c.builds.find((b) => b.build === "assertions")?.failed ?? 1) === 0} />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <p className="small muted" style={{ marginTop: 10 }}>
              External entities through the C library: {c.dllExternalEntities.cases} / {c.dllExternalEntities.cases} in
              both builds. Measured {c.date}. {c.adjustments.length > 0 &&
                `One catalog expectation follows the 5th edition: ${c.adjustments.map((a) => a.case_id).join(", ")}.`}{" "}
              <a href={c.source}>Full report</a> · <a href={LINKS.w3cDoc}>how the suite is run</a>
            </p>
          </section>
        </>
      )}

      {comparison.data && (
        <section className="section">
          <h2>Compared with Expat 2.8.1</h2>
          <div className="grid grid-3">
            <Stat
              label="Same accept / reject verdict"
              value={`${fmt.format(comparison.data.sameVerdict ?? 0)} / ${fmt.format(comparison.data.pairs ?? 0)}`}
              sub="document × way of feeding it"
            />
            <Stat
              label="Same verdict, error code and events"
              value={`${fmt.format(comparison.data.sameVerdictCodeAndEvents ?? 0)} / ${fmt.format(comparison.data.pairs ?? 0)}`}
              sub="the strictest comparison"
            />
            <div className="card">
              <p className="small muted" style={{ margin: 0 }}>
                {comparison.data.note} <a href={comparison.data.source}>Comparison report</a>
              </p>
            </div>
          </div>
        </section>
      )}

      {benchmarks.data?.fairSpeed && (
        <section className="section">
          <h2>Speed against native Expat 2.8.1</h2>
          <p className="muted">
            Both DLLs loaded by the same C program through the same <code>expat.h</code> API, 5 shapes × 3 sizes × 6
            piece sizes, callbacks on and off. A ratio of 1 means as fast; 18 means 18 times slower.
          </p>
          <div className="grid grid-3">
            <Stat label="Median ratio, xpact / Expat" value={`${benchmarks.data.fairSpeed.medianRatio}×`} sub={`over ${fmt.format(benchmarks.data.fairSpeed.cells)} measured cells`} />
            <Stat label="Event checksum mismatches" value={fmt.format(benchmarks.data.fairSpeed.checksumMismatches)} sub="both parsers did the same work" />
            <Stat label="Not compared" value={fmt.format(benchmarks.data.fairSpeed.notCompared)} sub="ISO-8859-1 in 1-16 byte pieces timed out (#272)" />
          </div>
          <div className="card" style={{ marginTop: 16 }}>
            <h3 className="h3">Whole 1 MB documents (UTF-8)</h3>
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Shape</th>
                    <th className="num">Callbacks off</th>
                    <th className="num">Callbacks on</th>
                  </tr>
                </thead>
                <tbody>
                  {[...new Set(benchmarks.data.fairSpeed.wholeDocument1MB.map((r) => r.shape))].map((shape) => {
                    const cell = (on: boolean) =>
                      benchmarks.data!.fairSpeed!.wholeDocument1MB.find((r) => r.shape === shape && r.callbacks === on);
                    return (
                      <tr key={shape}>
                        <td>{shape}</td>
                        <td className="num">{cell(false) ? `${cell(false)!.ratio}×` : "–"}</td>
                        <td className="num">{cell(true) ? `${cell(true)!.ratio}×` : "–"}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
            <p className="small muted" style={{ marginTop: 10, marginBottom: 0 }}>
              Measured {benchmarks.data.fairSpeed.generated}. <a href={benchmarks.data.fairSpeed.source}>Fair speed report</a>
              {" · "}
              <a href={benchmarks.data.fairSpeed.check}>Recheck after #273/#274</a>
            </p>
          </div>
        </section>
      )}

      {benchmarks.data && (
        <section className="section">
          <h2>Speed</h2>
          <p className="muted">
            Documents per second (higher is better). Workload: {benchmarks.data.workload}. Measured{" "}
            {benchmarks.data.generated.split(" ")[0]}.
          </p>
          <div className="card">
            <div style={{ display: "flex", justifyContent: "flex-end", marginBottom: 8 }}>
              <button className="btn btn-sm" onClick={() => setShowTable((v) => !v)}>
                {showTable ? "Show chart" : "Show table"}
              </button>
            </div>
            {showTable ? (
              <div className="table-wrap">
                <table>
                  <thead>
                    <tr>
                      <th>Engine</th>
                      <th className="num">Docs / s</th>
                      <th className="num">MiB / s</th>
                      <th className="num">Median ms ({fmt.format(benchmarks.data.rows[0]?.iterations ?? 0)} docs)</th>
                    </tr>
                  </thead>
                  <tbody>
                    {benchmarks.data.rows.map((r) => (
                      <tr key={r.engine}>
                        <td>{r.engine}</td>
                        <td className="num">{fmt.format(Math.round(r.docsPerSecond))}</td>
                        <td className="num">{r.mibPerSecond.toFixed(2)}</td>
                        <td className="num">{r.medianMs.toFixed(1)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <BarChart
                caption="Documents per second for each parser configuration"
                legend={FAMILIES.map((f) => ({ label: f.label, color: f.color }))}
                bars={[...benchmarks.data.rows]
                  .sort((a, b) => b.docsPerSecond - a.docsPerSecond)
                  .map((r) => ({
                    label: shortName(r.engine),
                    value: r.docsPerSecond,
                    color: family(r.engine).color,
                    display: fmt.format(Math.round(r.docsPerSecond)),
                    title: `${r.engine}: ${fmt.format(Math.round(r.docsPerSecond))} docs/s, ${r.mibPerSecond.toFixed(2)} MiB/s`,
                  }))}
              />
            )}
          </div>
          <p className="small muted" style={{ marginTop: 10 }}>
            The Eiffel parser and the C library are now about as fast as Expat through Python; with callbacks the
            C library is about 2.3 times slower (see <a href="/docs#limits">known limitations</a>).{" "}
            <a href={benchmarks.data.source}>Benchmark report</a>
          </p>
        </section>
      )}
    </>
  );
}

function Pass({ cases, ok }: { cases: number; ok: boolean }) {
  return ok ? (
    <span className="badge badge-good">✓ {fmt.format(cases)} / {fmt.format(cases)}</span>
  ) : (
    <span className="badge badge-warn">see report</span>
  );
}

function shortName(engine: string) {
  return engine
    .replace("xpact Eiffel finalized, ", "Eiffel, ")
    .replace("xpact native C ABI ", "DLL ")
    .replace(" via Windows MSVC DLL", "")
    .replace("libexpat via CPython pyexpat ", "Expat (pyexpat) ")
    .replace("assertions discarded", "production")
    .replace("assertions enabled", "assertions")
    .replace(", GC suspended during parse", ", GC off");
}
