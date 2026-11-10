interface Props {
  label: string;
  value: string;
  sub?: string;
  /** A long value (such as "2,585 / 2,585") in a smaller size, so it stays on one line. */
  long?: boolean;
  /** What the number means for the test: "✅ 0 crashes · 0 hangs", in green (good) or plain text (plain). */
  result?: { text: string; tone: "good" | "plain" };
}

/** A single headline number. */
export function Stat({ label, value, sub, long, result }: Props) {
  return (
    <div className="stat">
      <div className="label">{label}</div>
      <div className={long ? "value long" : "value"}>{value}</div>
      {sub && <div className="sub">{sub}</div>}
      {result && <div className={`result ${result.tone}`}>{result.text}</div>}
    </div>
  );
}
