import { AUTHOR, BRANCH, LINKS, repoFile, repoTree } from "../data/site";

// What the student built, with the evidence for each part.
const WORK: { area: string; what: string; href: string }[] = [
  { area: "Test automation", what: "11 test areas in Python: W3C, fuzzing, differential testing against Expat, security, memory, large files", href: repoTree("student/results/AlotOfTests-2026-10-28") },
  { area: "Parser fixes", what: "Conformance fixes in the Eiffel parser: W3C output test from 359 to 399 of 432", href: repoTree("reports") },
  { area: "DevOps: build and CI", what: "Windows native build (MSVC), PowerShell build scripts, Jenkins pipelines and SonarQube findings", href: repoFile("reports/README.md") },
  { area: "This website", what: "React + TypeScript front end, ASP.NET Core API with an isolated parser worker, xUnit tests", href: repoTree("website") },
];

// The website's own development phases (website/guide.txt), with their state.
const PHASES: { phase: number; deliverable: string; done: boolean; note: string }[] = [
  { phase: 1, deliverable: "XPact native library works reliably", done: true, note: "W3C 2,585 cases, 0 failed; DLL smoke tests" },
  { phase: 2, deliverable: "ASP.NET Core API can call XPact", done: true, note: "Isolated worker process per document" },
  { phase: 3, deliverable: "Postman tests for the API", done: true, note: "Postman collection, .http file, 19 xUnit end-to-end tests" },
  { phase: 4, deliverable: "React website with XML upload", done: true, note: "Paste, upload or drop a file" },
  { phase: 5, deliverable: "Display parsing errors and results", done: true, note: "Code, message, line/column, parser events" },
  { phase: 6, deliverable: "Documentation and benchmark pages", done: true, note: "Numbers exported from the repository reports" },
  { phase: 7, deliverable: "Public deployment and security testing", done: false, note: "Local security tests done; not deployed yet" },
];

export function Project() {
  return (
    <>
      <div className="page-head">
        <h1>Project</h1>
        <p>
          XPact is developed in the open. The source, the test reports and every bug report are on GitHub, and the
          website itself lives in the same repository, in <code>website/</code>.
        </p>
      </div>

      <section className="grid grid-3">
        <LinkCard title="Source code" href={LINKS.branch} text={`The ${BRANCH} branch: parser, C library, tests and this website.`} />
        <LinkCard title="Issues" href={LINKS.issues} text="One issue per bug, finding or task, each with a report and its evidence." />
        <LinkCard title="Project board" href={LINKS.board} text="What is being worked on: Todo → In progress → In review → Done." />
        <LinkCard title="Reports" href={LINKS.reports} text="Investigations, fixes and test runs, one folder per issue." />
        <LinkCard title="Plan" href={LINKS.plan} text="The weekly plan and the list of what is left to do." />
        <LinkCard title="Website docs" href={LINKS.websiteDocs} text="Architecture, REST API, security and how to run this site." />
      </section>

      <section className="section">
        <div className="grid grid-4">
          {WORK.map((w) => (
            <a key={w.area} className="card" href={w.href} style={{ color: "inherit" }}>
              <h2 className="h3" style={{ color: "var(--accent)" }}>{w.area} ↗</h2>
              <p className="muted small">{w.what}</p>
            </a>
          ))}
        </div>
        <p className="small muted" style={{ marginTop: 12 }}>
          <a href={AUTHOR.github}>GitHub profile ↗</a> · <a href={AUTHOR.pulls}>Merged pull requests ↗</a>
          {AUTHOR.linkedin && (
            <>
              {" "}
              · <a href={AUTHOR.linkedin}>LinkedIn ↗</a>
            </>
          )}
        </p>
      </section>

      <section className="section">
        <h2>Website roadmap</h2>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th className="num">Phase</th>
                <th>Deliverable</th>
                <th>Status</th>
                <th>Notes</th>
              </tr>
            </thead>
            <tbody>
              {PHASES.map((p) => (
                <tr key={p.phase}>
                  <td className="num">{p.phase}</td>
                  <td>{p.deliverable}</td>
                  <td>{p.done ? <span className="badge badge-good">✅ done</span> : <span className="badge">⬜ to do</span>}</td>
                  <td className="muted">{p.note}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="section grid grid-2">
        <div className="card">
          <h2>How the website works</h2>
          <ol className="muted" style={{ paddingLeft: 20 }}>
            <li>The browser sends your XML to the API.</li>
            <li>The API checks the size and the request rate.</li>
            <li>It starts a separate worker process with a memory cap and a time limit.</li>
            <li>The worker calls <code>xpact.dll</code> and returns the result as JSON.</li>
            <li>The page shows the verdict, the error position and the events.</li>
          </ol>
          <p className="small muted" style={{ margin: 0 }}>
            The website is one client of the parser; XPact does not depend on it.{" "}
            <a href={repoFile("website/docs/architecture.md")}>Architecture</a>
          </p>
        </div>
        <div className="card">
          <h2>Report a problem</h2>
          <p className="muted">
            Found a document where XPact disagrees with the XML specification or with Expat? Open an issue with the XML,
            what you expected and what the validator showed. The raw JSON response (under each result) has everything
            needed.
          </p>
          <a className="btn" href={`${LINKS.issues}/new`}>
            Open an issue ↗
          </a>
        </div>
      </section>
    </>
  );
}

function LinkCard({ title, href, text }: Readonly<{ title: string; href: string; text: string }>) {
  return (
    <a className="card" href={href} style={{ color: "inherit" }}>
      <h2 className="h3" style={{ color: "var(--accent)" }}>{title} ↗</h2>
      <p className="muted small">{text}</p>
    </a>
  );
}
