import { useEffect, useRef, useState, type ChangeEvent } from "react";
import { ApiError, getInfo, validateFile, validateText } from "../api/client";
import type { ServerInfo, ValidationResult } from "../api/types";
import { ResultPanel } from "../components/ResultPanel";
import { XmlEditor, type XmlEditorHandle } from "../components/XmlEditor";
import { SAMPLES } from "../data/samples";

const fmtBytes = (n: number) => (n >= 1024 * 1024 ? `${(n / 1024 / 1024).toFixed(1)} MB` : `${Math.round(n / 1024)} KB`);

export function Validator() {
  const [text, setText] = useState(SAMPLES[0].xml);
  // An uploaded file is sent with its original bytes until the text is edited.
  const [file, setFile] = useState<File | null>(null);
  const [build, setBuild] = useState("production");
  const [chunked, setChunked] = useState(false);
  const [chunkSize, setChunkSize] = useState(1);
  const [result, setResult] = useState<ValidationResult | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<ServerInfo | null>(null);
  const editor = useRef<XmlEditorHandle>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  useEffect(() => {
    getInfo()
      .then(setInfo)
      .catch(() => setError("The XPact API is not reachable. Is the server running?"));
  }, []);

  async function loadFile(f: File) {
    setResult(null);
    setError(null);
    if (info && f.size > info.limits.maxDocumentBytes) {
      setError(`${f.name} is ${fmtBytes(f.size)}; the limit is ${fmtBytes(info.limits.maxDocumentBytes)}.`);
      return;
    }
    setFile(f);
    // Shown as UTF-8 for reading; the parser still gets the file's own bytes.
    setText(await f.text());
  }

  function onPick(e: ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0];
    if (f) void loadFile(f);
    e.target.value = "";
  }

  async function validate() {
    setBusy(true);
    setError(null);
    try {
      const options = { build, chunkSize: chunked ? Math.max(1, chunkSize) : 0 };
      setResult(file ? await validateFile(file, options) : await validateText(text, options));
    } catch (e) {
      setResult(null);
      setError(e instanceof ApiError ? `${e.title}: ${e.message}` : "The request failed. Is the server running?");
    } finally {
      setBusy(false);
    }
  }

  const markLine = result?.error?.line ?? 0;

  return (
    <>
      <div className="page-head">
        <h1>XML validator</h1>
        <p>
          Paste a document or upload a file. XPact parses it on the server through its Expat-compatible C API and
          tells you whether it is <strong>well-formed</strong>. If not, it shows the error, with its line and column.
          Documents are not stored.
        </p>
      </div>

      <div className="validator">
        <div>
          <div className="toolbar">
            <button className="btn btn-sm" onClick={() => fileInput.current?.click()}>
              ⤒ Upload file
            </button>
            <input ref={fileInput} type="file" accept=".xml,.xsd,.xsl,.svg,.rss,.atom,text/xml,application/xml" hidden onChange={onPick} />
            <select
              aria-label="Load an example"
              value=""
              onChange={(e) => {
                const s = SAMPLES.find((x) => x.id === e.target.value);
                if (s) {
                  setFile(null);
                  setText(s.xml);
                  setResult(null);
                }
              }}
            >
              <option value="">Load an example…</option>
              {SAMPLES.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.label}
                </option>
              ))}
            </select>
            <button
              className="btn btn-sm"
              onClick={() => {
                setText("");
                setFile(null);
                setResult(null);
              }}
            >
              Clear
            </button>
            {file && (
              <span className="file-chip" title="The original bytes of this file are sent to the parser">
                📄 {file.name} · {fmtBytes(file.size)}
                <button aria-label="Use the editor text instead" onClick={() => setFile(null)}>
                  ×
                </button>
              </span>
            )}
          </div>

          <XmlEditor
            ref={editor}
            value={text}
            markLine={markLine}
            onFile={(f) => void loadFile(f)}
            onChange={(v) => {
              setText(v);
              setFile(null); // edited: send the text, not the file
            }}
          />

          <div className="options">
            <label>
              Parser build
              <select value={build} onChange={(e) => setBuild(e.target.value)}>
                {(info?.builds ?? [{ name: "production", available: true }]).map((b) => (
                  <option key={b.name} value={b.name} disabled={!b.available}>
                    {b.name === "production" ? "Production (fast)" : "Assertions (contracts checked)"}
                    {b.available ? "" : " – not installed"}
                  </option>
                ))}
              </select>
            </label>
            <label>
              Feed the document
              <select value={chunked ? "chunks" : "whole"} onChange={(e) => setChunked(e.target.value === "chunks")}>
                <option value="whole">In one piece</option>
                <option value="chunks">In pieces (streaming)</option>
              </select>
            </label>
            {chunked && (
              <label>
                Piece size (bytes)
                <input
                  type="number"
                  min={1}
                  max={65536}
                  value={chunkSize}
                  onChange={(e) => setChunkSize(Number(e.target.value))}
                  style={{ width: 110 }}
                />
              </label>
            )}
            <span className="grow" />
            <button
              className="btn btn-primary"
              onClick={() => void validate()}
              disabled={busy || (!file && text.length === 0)}
            >
              {busy ? "Parsing…" : "Validate ▸"}
            </button>
          </div>
          {info && (
            <p className="muted small" style={{ marginTop: 10 }}>
              Limits: {fmtBytes(info.limits.maxDocumentBytes)} per document · {info.limits.timeoutSeconds} s per parse ·{" "}
              {info.limits.requestsPerMinute} requests per minute. External entities and DTDs are never fetched.
            </p>
          )}
        </div>

        <div>
          {error && (
            <div className="alert" role="alert" style={{ marginBottom: 14 }}>
              {error}
            </div>
          )}
          {result ? (
            <ResultPanel result={result} onGoToLine={(line) => editor.current?.goToLine(line)} />
          ) : (
            <div className="empty-state">
              <p style={{ fontSize: "1.05rem", marginBottom: 6 }}>No result yet</p>
              <p className="small" style={{ margin: 0 }}>
                Press <strong>Validate</strong> to parse the document. Try “In pieces” with a size of 1: the verdict must
                not change, however the document is cut.
              </p>
            </div>
          )}
        </div>
      </div>
    </>
  );
}
