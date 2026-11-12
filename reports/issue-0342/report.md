# #342 · SonarQube issue 9: security hotspots

| | |
|---|---|
| Status | ✅ SHA-1 hotspot resolved in code (3 → 2 hotspots) · 🟡 `killpg` (and the ECF namespace, see below) to be marked **Safe** in the SonarQube UI |
| Issue | [#342](https://github.com/andersoxie/xpact/issues/342) |
| File changed | `scripts/prepare_xpact_core.py` |

| Hotspot | Where | Verdict | Action |
|---|---|---|---|
| S4790 weak hash | `prepare_xpact_core._hash_tree_entry`: `hashlib.sha1(...)` | ✅ safe: recomputes **git's own blob id** (`sha1("blob <size>\0" + content)`), which git defines as SHA-1, to compare files with the pinned commit. The security check is the SHA-256 `source_sha256` over every file. | `usedforsecurity=False` + comment; SonarQube no longer reports it |
| S4828 sending signals | `run_probe.run`: `os.killpg(process.pid, SIGKILL)` | ✅ safe: the child is started with `start_new_session=True`, so `process.pid` names a new process group that holds only that compiler and its children. The signal stops exactly that group after a timeout or interruption; no other process can be reached. | no code change; mark **Safe** in SonarQube |
| S5332 clear-text protocol (expected) | `run_probe.py`: ECF namespace `http://www.eiffel.com/developers/xml/configuration-1-...` | ✅ safe: an XML namespace name that EiffelStudio requires literally; nothing connects to it | no code change; mark **Safe** |

- **Environment:** student PC, uv CPython 3.15; project needs Python 3.11+ (#113), `usedforsecurity` exists since 3.9.
- **Cause:** ✅ confirmed by reading the code: no weakness.

## Verification

| Check | Result |
|---|---|
| `sha1(..., usedforsecurity=False)` of `hello\n` vs `git hash-object --stdin` | ✅ same id |
| `python -m unittest discover -s tests/python -p "test_implementation*.py"` | ✅ Ran 33, OK |
| SonarQube rescan of `fix/342-sonar-hotspots` (2026-11-12) | ✅ security hotspots 3 → **2**, code smells 0 |

The student account gets HTTP 403 on `api/hotspots/search`, so the two remaining hotspots are named from the UI and from SonarQube for IDE.

## Marking as Safe (SonarQube UI)

Security Hotspots → select the hotspot → **Review** → status **Safe** → paste the reason from the table above.
