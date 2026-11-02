import type { ValidationResult } from "../api/types";

interface Props {
  result: ValidationResult;
  onGoToLine(line: number): void;
}

const fmt = new Intl.NumberFormat("en");

export function ResultPanel({ result, onGoToLine }: Props) {
  const e = result.error;
  const problem = result.verdict !== "accepted" && result.verdict !== "rejected";
  const kind = problem ? "problem" : result.verdict;
  const title = {
    accepted: "Well-formed: accepted",
    rejected: "Not well-formed: rejected",
    timeout: "Stopped: time limit reached",
    crashed: "The parser process stopped",
    error: "Could not run the parser",
  }[result.verdict];
  const icon = { accepted: "✓", rejected: "✕" }[result.verdict as "accepted" | "rejected"] ?? "!";

  return (
    <div className="result" aria-live="polite">
      <div className={`verdict ${kind}`}>
        <div className="title">
          <span className="icon" aria-hidden="true">
            {icon}
          </span>
          {title}
        </div>
        {e && (
          <div className="detail">
            <strong>{e.message}</strong> <span className="badge">code {e.code}</span>
            <div className="where">
              line {e.line}, column {e.column + 1} · byte {fmt.format(e.byteIndex)}{" "}
              {e.line > 0 && (
                <button className="btn btn-sm" onClick={() => onGoToLine(e.line)}>
                  Show in editor
                </button>
              )}
            </div>
          </div>
        )}
        {result.diagnostic && <div className="detail">{result.diagnostic}</div>}
      </div>

      <dl className="kv">
        <div>
          <dt>Parse time</dt>
          <dd>{result.parseMs.toFixed(2)} ms</dd>
        </div>
        <div>
          <dt>Request</dt>
          <dd>{Math.round(result.totalMs)} ms</dd>
        </div>
        <div>
          <dt>Size</dt>
          <dd>{fmt.format(result.inputBytes)} B</dd>
        </div>
        <div>
          <dt>Build</dt>
          <dd>{result.build}</dd>
        </div>
        <div>
          <dt>Fed as</dt>
          <dd>
            {result.mode === "whole"
              ? "whole"
              : `${fmt.format(result.parseCalls)} × ${result.chunkSize} B`}
          </dd>
        </div>
        {result.version && (
          <div>
            <dt>API version</dt>
            <dd>{result.version}</dd>
          </div>
        )}
      </dl>

      {!problem && (
        <div className="card">
          <h3>Parser events</h3>
          <p className="muted small">
            What XPact reported through the Expat callbacks, in document order
            {result.events.truncated ? ` (first ${result.events.sample.length} shown)` : ""}.
            {result.verdict === "rejected" && " Events before the error are still delivered."}
          </p>
          <div className="grid grid-4" style={{ marginBottom: 12 }}>
            <Count label="Start tags" value={result.events.startElements} />
            <Count label="End tags" value={result.events.endElements} />
            <Count label="Text runs" value={result.events.textChunks} />
            <Count label="Comments / PIs" value={result.events.comments + result.events.processingInstructions} />
          </div>
          {result.events.sample.length > 0 ? (
            <div className="table-wrap" style={{ maxHeight: 320, overflowY: "auto" }}>
              <table className="events-table">
                <thead>
                  <tr>
                    <th className="num">Line</th>
                    <th>Event</th>
                    <th>Name</th>
                    <th>Value</th>
                  </tr>
                </thead>
                <tbody>
                  {result.events.sample.map((ev, i) => (
                    <tr key={i}>
                      <td className="num">{ev.line}</td>
                      <td className="kind">{ev.kind}</td>
                      <td className="kind">{ev.name}</td>
                      <td className="val">{ev.value}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <p className="muted small">No events.</p>
          )}
        </div>
      )}

      <details className="raw">
        <summary>Raw JSON response</summary>
        <pre>{JSON.stringify(result, null, 2)}</pre>
      </details>
    </div>
  );
}

function Count({ label, value }: { label: string; value: number }) {
  return (
    <div className="stat" style={{ padding: "10px 12px" }}>
      <div className="label">{label}</div>
      <div className="value" style={{ fontSize: "1.3rem" }}>
        {fmt.format(value)}
      </div>
    </div>
  );
}
