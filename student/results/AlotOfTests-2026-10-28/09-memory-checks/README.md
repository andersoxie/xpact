# 9 · Memory checks

> **Question:** Does `xpact.dll` leak memory when parsers are created, used and freed many times?
> **Status:** ✅ run (2026-10-28) · ✅ **no leak**: memory levels off in every scenario · nothing changed in xpact

[⬅ back to AlotOfTests](../README.md)

## In short

[leak.py](leak.py) runs each scenario **20,000 times** in a fresh process (create → parse → free) and samples the private memory at 10 %, 25 %, 50 %, 75 % and 100 % of the rounds.
- **A leak** keeps growing with the number of rounds.
- **No leak** levels off.

Expat runs the same scenarios as a control for the Python harness.

| Scenario | xpact memory (MB) at 10 / 25 / 50 / 75 / 100 % | After 50 % | Expat (control) |
|---|---|---|---|
| small document (all event kinds) | 29.4 / 31.6 / 32.6 / 32.6 / 32.6 | ✅ flat | 12.0 → 14.8 |
| DTD, entities, defaults | 29.7 / 31.8 / 32.9 / 32.9 / 32.9 | ✅ flat | 11.9 → 18.7 |
| namespaces | 29.6 / 32.7 / 32.7 / 32.7 / 32.7 | ✅ flat | 11.6 → 15.3 |
| document with an error | 29.8 / 30.9 / 34.1 / 34.1 / 34.1 | ✅ flat | 12.0 → 14.8 |
| byte by byte (many `XML_Parse` calls) | 29.8 / 31.9 / 32.9 / 32.9 / 32.8 | ✅ flat | 12.2 → 19.4 |
| external entity (child parser created and freed) | 33.0 / 35.1 / 35.1 / 35.1 / 35.1 | ✅ flat | 12.6 → 22.3 |
| one parser, `XML_ParserReset` + parse 20,000 times | 27.5 / 27.5 / 27.5 / 27.5 / 27.5 | ✅ flat | (not available in pyexpat) |
| small billion laughs (10⁵ characters per parse) | 104.2 / 191.0 / 240.9 / 244.0 / 242.2 | ✅ levels off (high: about 240 MB of garbage-collector heap) | 73.2 → 315.7 |

- The first 3–5 MB in xpact are the Eiffel garbage collector growing its heap at the start; after that, nothing grows.
- The Expat column grows slowly because of the Python harness (event lists), not because of Expat. xpact goes through the same harness and stays flat, so the harness does not hide a leak.

Result: [logs/leak-xpact.json](logs/leak-xpact.json) · console: [logs/leak-xpact.txt](logs/leak-xpact.txt)

> A first run with 2,000 rounds showed the external-entity scenario growing (4 MB). The 20,000-round run shows that this was the warm-up: it stops at 35.1 MB.

## Limitations

- Process memory only. A small leak (bytes per parse) would need about 1 million rounds or a tool like Dr. Memory / Application Verifier, which is not installed on this PC.
- No check for reading or writing outside a buffer that does not crash (needs AddressSanitizer; the Eiffel/MSVC build does not have it).
- Normal build only.

## To do

- [ ] Assertions build (`python leak.py --dll …\xpact_assertions.dll --tag xpact_assertions`)
- [ ] Dr. Memory, if it can be installed
