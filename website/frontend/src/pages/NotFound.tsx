import { Link } from "react-router-dom";

export function NotFound() {
  return (
    <div className="empty-state" style={{ marginTop: 40 }}>
      <h1>Page not found</h1>
      <p>
        <Link to="/">Back to the home page</Link> or <Link to="/validator">try the validator</Link>.
      </p>
    </div>
  );
}
