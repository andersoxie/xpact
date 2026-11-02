# REST API

[← website README](../README.md)

Base URL: the site itself (for example `http://localhost:5099`). All responses are JSON. Ready-made requests: [`backend/requests/xpact-api.http`](../backend/requests/xpact-api.http) and the [Postman collection](../backend/requests/xpact-api.postman_collection.json).

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/health` | `{"status":"ok"}` when the API runs |
| `GET` | `/api/info` | the builds (and whether each DLL is installed) and the limits |
| `POST` | `/api/validate` | parse one document |
| `GET` | `/api/results/{name}` | `conformance`, `benchmarks` or `comparison` (exported report data) |

## `POST /api/validate`

Send the document in **one** of three ways:

| Content type | Document | Options |
|---|---|---|
| `multipart/form-data` | field `file` (sent as is) or field `xml` (text) | fields `build`, `chunkSize` |
| `application/json` | `{"xml": "…"}` (UTF-8) | `build`, `chunkSize` properties |
| anything else, e.g. `application/xml` | the raw body | query `?build=…&chunkSize=…` |

| Option | Values | Default |
|---|---|---|
| `build` | `production` (contracts off) or `assertions` (every contract checked) | `production` |
| `chunkSize` | `0` = the whole document in one `XML_Parse` call; `n ≥ 1` = pieces of `n` bytes, the last one final | `0` |

```bash
curl --data-binary @doc.xml -H "Content-Type: application/xml" "http://localhost:5099/api/validate?build=assertions"
curl -H "Content-Type: application/json" -d '{"xml":"<a><b></a>","chunkSize":1}' http://localhost:5099/api/validate
curl -F file=@doc.xml -F build=production http://localhost:5099/api/validate
```

### The result

`200 OK` whenever the parser ran, **whether or not the document is well-formed**:

```json
{
  "parser": "XPact",
  "version": "expat_2.8.1",
  "build": "production",
  "verdict": "rejected",
  "wellFormed": false,
  "parseMs": 2.58,
  "totalMs": 129.3,
  "inputBytes": 61,
  "mode": "whole",
  "chunkSize": 0,
  "parseCalls": 1,
  "error": { "code": 7, "message": "mismatched tag", "line": 3, "column": 15, "byteIndex": 47 },
  "events": {
    "startElements": 3, "endElements": 1, "textChunks": 4, "comments": 0, "processingInstructions": 0,
    "sample": [ { "kind": "start", "name": "order", "value": "", "line": 1 } ],
    "truncated": false
  },
  "diagnostic": null
}
```

| Field | Meaning |
|---|---|
| `verdict` | `accepted` · `rejected` · `timeout` (killed after the time limit) · `crashed` (the worker ended without a result) · `error` (the server could not run the parser) |
| `version` | what `XML_ExpatVersion()` returns: the Expat API version XPact follows |
| `parseMs` | time inside `XML_Parse` calls (worker) |
| `totalMs` | the whole request, including starting the worker |
| `error.code` | Expat-compatible error code (`XML_GetErrorCode`) |
| `error.line` | 1-based line |
| `error.column` | **0-based** column, as Expat reports it (the site shows column + 1) |
| `events.sample` | the first events (max 200) in document order; whitespace-only text is counted but not listed |
| `diagnostic` | why a `timeout`, `crashed` or `error` verdict happened |

### Errors (no parse happened)

Returned as [RFC 9457 problem details](https://www.rfc-editor.org/rfc/rfc9457) (`title`, `detail`):

| Status | When |
|---|---|
| `400` | no document, an unknown build, a negative chunk size, or an unreadable request |
| `413` | the document is larger than the limit (1 MB by default) |
| `429` | more than 30 requests per minute from one IP |

## Limits

All in `backend/src/Xpact.Api/appsettings.json`, section `Xpact`:

| Setting | Default |
|---|---|
| `MaxDocumentBytes` | 1,048,576 |
| `TimeoutSeconds` | 10 |
| `WorkerMemoryMb` | 512 |
| `MaxConcurrentWorkers` | 4 |
| `RequestsPerMinute` | 30 |
| `MaxEvents` | 200 |
| `Builds` | `production` → `native/xpact.dll`, `assertions` → `native/xpact_assertions.dll` |
