import { forwardRef, useImperativeHandle, useRef, useState, type DragEvent } from "react";

export interface XmlEditorHandle {
  /** Scroll to a 1-based line and put the cursor at its start. */
  goToLine(line: number): void;
}

interface Props {
  value: string;
  onChange(value: string): void;
  onFile(file: File): void;
  /** 1-based line to mark (the error line), or 0. */
  markLine: number;
  /** Show the text without editing (the preview of a large file). */
  readOnly?: boolean;
}

/**
 * A plain textarea with a line-number gutter and an error-line marker.
 * Dropping a file on it hands the File to the page (the original bytes are kept).
 */
export const XmlEditor = forwardRef<XmlEditorHandle, Props>(function XmlEditor(
  { value, onChange, onFile, markLine, readOnly = false },
  ref,
) {
  const textarea = useRef<HTMLTextAreaElement>(null);
  const gutter = useRef<HTMLDivElement>(null);
  const highlight = useRef<HTMLDivElement>(null);
  const [dragging, setDragging] = useState(false);
  const lines = value.split("\n");
  // Keyed by line number: a stable identity for each row (SonarQube S6479, #329).
  const numbered = lines.map((text, index) => ({ number: index + 1, text }));

  useImperativeHandle(ref, () => ({
    goToLine(line: number) {
      const el = textarea.current;
      if (!el) return;
      const index = lines.slice(0, Math.max(0, line - 1)).reduce((n, l) => n + l.length + 1, 0);
      el.focus();
      el.setSelectionRange(index, index + (lines[line - 1]?.length ?? 0));
      el.scrollTop = Math.max(0, (line - 4) * 20);
      syncScroll();
    },
  }));

  function syncScroll() {
    const el = textarea.current;
    if (!el) return;
    if (gutter.current) gutter.current.scrollTop = el.scrollTop;
    if (highlight.current) {
      highlight.current.scrollTop = el.scrollTop;
      highlight.current.scrollLeft = el.scrollLeft;
    }
  }

  function onDrop(e: DragEvent) {
    e.preventDefault();
    setDragging(false);
    const file = e.dataTransfer.files?.[0];
    if (file) onFile(file);
  }

  return (
    <section
      aria-label="XML editor: type or paste XML, or drop a .xml file"
      className={`editor${dragging ? " dragging" : ""}`}
      onDragOver={(e) => {
        e.preventDefault();
        setDragging(true);
      }}
      onDragLeave={() => setDragging(false)}
      onDrop={onDrop}
    >
      <div className="gutter" ref={gutter} aria-hidden="true">
        {numbered.map((row) => (
          <div key={row.number} className={row.number === markLine ? "err" : undefined}>
            {row.number}
          </div>
        ))}
      </div>
      <div className="area">
        <div className="highlight" ref={highlight} aria-hidden="true">
          {numbered.map((row) => (
            <div key={row.number}>
              {row.number === markLine ? <span className="line-mark">{row.text || " "}</span> : row.text || " "}
            </div>
          ))}
        </div>
        <textarea
          ref={textarea}
          value={value}
          readOnly={readOnly}
          spellCheck={false}
          autoCapitalize="off"
          autoComplete="off"
          aria-label="XML document"
          placeholder="Paste XML here, or drop a .xml file…"
          onChange={(e) => onChange(e.target.value)}
          onScroll={syncScroll}
        />
      </div>
      {dragging && <div className="drop-hint">Drop the XML file to test it</div>}
    </section>
  );
});
