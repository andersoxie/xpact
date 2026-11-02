interface Props {
  label: string;
  value: string;
  sub?: string;
  /** A long value (such as "2,585 / 2,585") in a smaller size, so it stays on one line. */
  long?: boolean;
}

/** A single headline number. */
export function Stat({ label, value, sub, long }: Props) {
  return (
    <div className="stat">
      <div className="label">{label}</div>
      <div className={long ? "value long" : "value"}>{value}</div>
      {sub && <div className="sub">{sub}</div>}
    </div>
  );
}
