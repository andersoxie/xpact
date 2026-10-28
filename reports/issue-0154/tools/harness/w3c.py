"""W3C catalog access, reusing the project's own runner (scripts/run_w3c_conformance.py).

cases() returns the runner's Case objects plus the catalog attributes (for OUTPUT).
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

# reports/issue-0154/tools/harness/w3c.py -> repository root; XPACT_REPO overrides it.
REPO = Path(os.environ.get("XPACT_REPO") or Path(__file__).resolve().parents[4])
SUITE = REPO / "build" / "validation-corpora" / "w3c-xml-20130923" / "xmlconf"
sys.path.insert(0, str(REPO / "scripts"))
import run_w3c_conformance as runner  # noqa: E402


def cases(suite=SUITE):
    attributes = {}
    original = runner.expectation

    def capture(attrs):
        attributes[attrs["ID"]] = dict(attrs)
        return original(attrs)

    runner.expectation = capture
    try:
        loaded = runner.load_catalog(suite)
    finally:
        runner.expectation = original
    return [(case, attributes[case.id]) for case in loaded]
