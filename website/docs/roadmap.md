# Roadmap

[← website README](../README.md)

The 7 phases from [guide.txt](../guide.txt), section 6.

| Phase | Deliverable | Status | Evidence |
|---:|---|---|---|
| 1 | XPact native library works reliably | ✅ | W3C 2,585 cases, 0 failed, both builds ([report](../../reports/latest-2026-10-28/README.md)); DLL smoke tests ok on 2026-11-02 |
| 2 | ASP.NET Core API can call XPact | ✅ | `Xpact.Api` + `Xpact.Worker` ([architecture](architecture.md)) |
| 3 | Postman tests for the API | ✅ | [Postman collection](../backend/requests/xpact-api.postman_collection.json), [.http file](../backend/requests/xpact-api.http), 19 xUnit end-to-end tests ([testing](testing.md)) |
| 4 | React website with XML upload | ✅ | Validator page: paste, upload, drag and drop |
| 5 | Display parsing errors and results | ✅ | Verdict, code, message, line/column, error line marked, events |
| 6 | Documentation and benchmark pages | ✅ | Documentation and Benchmarks pages, data from `reports/` |
| 7 | Public deployment and security testing | 🟡 | Local security tests ✅ ([security](security.md)); deployment ⬜ |

## Next

- [ ] Choose the host and deploy: Docker image `website-2026-11-14-3` and [hosting checklist](docker.md#hosting-on-the-internet-safely) are ready (supervisor, [#210](https://github.com/andersoxie/xpact/issues/210))
- [x] ✅ Low-privilege worker: Low integrity, no privileges ([#299](https://github.com/andersoxie/xpact/issues/299)) ([security.md](security.md#known-gaps-before-a-public-deployment)). Forwarded headers are done (#224); HTTPS is the supervisor's.
- [x] ✅ Code-review findings 1-2 fixed ([#295](https://github.com/andersoxie/xpact/issues/295), [#297](https://github.com/andersoxie/xpact/issues/297)) ([security.md](security.md#findings-from-the-code-review-2026-11-11))
- [x] Open a GitHub issue for the entity-expansion finding: [#211](https://github.com/andersoxie/xpact/issues/211) ([report](../../reports/issue-0211/report.md))
- [ ] Fix #211 in the parser (not part of the website)
- [ ] Compare with Expat live: an optional second worker that runs the same document through `libexpat.dll` and shows both results side by side
- [ ] Namespaces option in the validator (`XML_ParserCreateNS`)
- [ ] Refresh the benchmark numbers (`docs/benchmarks.md` is from 2026-06-21)
