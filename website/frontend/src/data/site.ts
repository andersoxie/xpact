// Links and facts shown on several pages. One place to update them.

export const REPO = "https://github.com/andersoxie/xpact";
export const BRANCH = "incremental-test";
export const repoFile = (path: string) => `${REPO}/blob/${BRANCH}/${path}`;
export const repoTree = (path: string) => `${REPO}/tree/${BRANCH}/${path}`;

export const LINKS = {
  repo: REPO,
  branch: repoTree(""),
  issues: `${REPO}/issues`,
  pulls: `${REPO}/pulls`,
  board: "https://github.com/users/CodTanium/projects/3",
  header: repoFile("include/xpact.h"),
  plan: repoFile("student/PLAN.md"),
  reports: repoTree("reports"),
  w3cDoc: repoFile("docs/w3c-xml-conformance.md"),
  websiteDocs: repoTree("website/docs"),
  expat: "https://libexpat.github.io/",
  w3cSuite: "https://www.w3.org/XML/Test/",
  xmlSpec: "https://www.w3.org/TR/2008/REC-xml-20081126/",
  issue: (n: number) => `${REPO}/issues/${n}`,
  massIssue: (n: number) => `https://github.com/CodTanium/mass-xpact/issues/${n}`,
};

// Who did the testing, the fixes and this website (footer and Project page).
// Leave linkedin empty to hide that link.
export const AUTHOR = {
  name: "Masoud Dehdar",
  role: "Software Developer (internship), Bsharp, Sep–Nov 2026 (10 weeks)",
  github: "https://github.com/CodTanium",
  linkedin: "",
  pulls: `${REPO}/pulls?q=is%3Apr+is%3Amerged+author%3ACodTanium`,
};
