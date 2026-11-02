export interface Bar {
  label: string;
  value: number;
  /** CSS colour token, e.g. "var(--series-1)". */
  color: string;
  /** Text after the bar; defaults to the value. */
  display?: string;
  title?: string;
}

interface Props {
  bars: Bar[];
  legend?: { label: string; color: string }[];
  /** Screen-reader summary of the chart. */
  caption: string;
}

/**
 * Horizontal bars on one shared linear scale, starting at zero.
 * Every bar is labelled with its value, so colour is never the only cue.
 */
export function BarChart({ bars, legend, caption }: Props) {
  const max = Math.max(...bars.map((b) => b.value), 1);
  return (
    <figure style={{ margin: 0 }}>
      {legend && legend.length > 1 && (
        <div className="legend">
          {legend.map((l) => (
            <span key={l.label}>
              <i style={{ background: l.color }} />
              {l.label}
            </span>
          ))}
        </div>
      )}
      <div className="bar-chart" role="img" aria-label={caption}>
        {bars.map((b) => (
          <div className="bar-row" key={b.label} title={b.title ?? `${b.label}: ${b.display ?? b.value}`}>
            <span className="name">{b.label}</span>
            <span className="bar-track">
              <span
                className="bar-fill"
                style={{ display: "block", width: `${(b.value / max) * 100}%`, background: b.color }}
              />
            </span>
            <span className="value">{b.display ?? b.value}</span>
          </div>
        ))}
      </div>
    </figure>
  );
}
