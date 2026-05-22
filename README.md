# xpact

xpact is an Eiffel XML parser project inspired by Finnian Reilly's Eiffel.org proposal, "Finding a billion-user project for Eiffel: How DbC catches the security flaws that Rust misses."

Tagline: **XML parsing, by contract.**

The Phase 1 target is a credible contracted parser release:

- pass the libexpat test suite,
- publish honest benchmark results,
- keep the Design by Contract annotations visible in source.

This checkpoint contains a contract-enabled Eiffel streaming parser core, XML 1.0 tokenization, internal/external entity handling through an opt-in resolver policy, a SAX-style event handler interface, test and benchmark ECF targets, a published same-machine benchmark table, a libexpat 2.8.1-compatible public API header/manifest, a bridge-only native DLL/SO export layer, and an upstream libexpat test-suite adapter.

## Build

```powershell
ec -batch -config tests\xpact_tests.ecf -target xpact_tests
.\EIFGENs\xpact_tests\W_code\xpact_tests.exe
```

See [docs/phase-1.md](docs/phase-1.md), [docs/benchmarks.md](docs/benchmarks.md), and [docs/libexpat-api-compatibility.md](docs/libexpat-api-compatibility.md) for the current scope and remaining Phase 1 work.
