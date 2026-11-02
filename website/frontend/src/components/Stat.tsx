interface Props {
  label: string;
  value: string;
  sub?: string;
}

/** A single headline number. */
export function Stat({ label, value, sub }: Props) {
  return (
    <div className="stat">
      <div className="label">{label}</div>
      <div className="value">{value}</div>
      {sub && <div className="sub">{sub}</div>}
    </div>
  );
}
