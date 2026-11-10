# Load test

How many visitors the website handles at once before answers get slow.

| Item | Value |
|---|---|
| Date | 2026-11-10 |
| Code | `incremental-test` @ `68abdcb`, API built `-c Release`, DLLs `xpact.dll` `4513b4a2…` (2026-11-08 build) |
| Machine | student PC: Windows 11, AMD Ryzen 7 5800H (8 cores / 16 threads); API and test client on the same PC |
| Settings | defaults (4 workers at once, 10 s timeout, 512 MB per worker), except the rate limit raised to 100,000 / min so it does not stop the test |
| Tool | [`website/backend/tests/tools/load-test.py`](../backend/tests/tools/load-test.py), 64 requests per level |

## Summary

- ✅ **No request failed** at any level: every answer was `accepted`.
- The site does about **40 requests/s** for tiny documents and **31 requests/s** for a 100 KB document.
- Up to **4 visitors at once** each wait about 0.1 s. Above 4 the extra requests queue: the wait grows in a straight line (32 at once: about 0.8-1 s each).
- The cost is mostly starting one worker process per document (~90 ms), not parsing.

## Results

Tiny document (`<a/>`):

| Visitors at once | Requests/s | Median ms | 95th pct ms | Max ms | Not accepted |
|---:|---:|---:|---:|---:|---:|
| 1 | 10.5 | 88 | 111 | 251 | 0 |
| 4 | 36.9 | 103 | 126 | 126 | 0 |
| 8 | 41.3 | 193 | 200 | 200 | 0 |
| 16 | 40.9 | 386 | 396 | 400 | 0 |
| 32 | 41.0 | 756 | 792 | 794 | 0 |

100 KB document (5,000 elements):

| Visitors at once | Requests/s | Median ms | 95th pct ms | Max ms | Not accepted |
|---:|---:|---:|---:|---:|---:|
| 1 | 8.6 | 111 | 131 | 140 | 0 |
| 4 | 30.9 | 125 | 145 | 149 | 0 |
| 8 | 32.0 | 249 | 259 | 260 | 0 |
| 16 | 31.7 | 490 | 528 | 543 | 0 |
| 32 | 30.7 | 988 | 1053 | 1064 | 0 |

## Command

```powershell
cd website\backend\src\Xpact.Api\bin\Release\net10.0\win-x64
$env:Xpact__RequestsPerMinute = "100000"; .\Xpact.Api.exe --urls http://localhost:5199
# second window
python website\backend\tests\tools\load-test.py --doc small
python website\backend\tests\tools\load-test.py --doc 100kb
```

## For the server

- With the normal rate limit (30 per minute per visitor) one visitor cannot load the site much; the limit is the 4-worker queue.
- On a server with more cores, `Xpact:MaxConcurrentWorkers` can be raised; measure again there.
- Not tested: large documents (the limit was 1 MB then, 10 MB since 2026-11-10), slow networks, HTTPS in front, a different machine.
