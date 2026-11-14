"""Tests for the fair speed scripts (#275) and the website data export.

benchmarks/fair_speed/summarize.py, benchmarks/fair_speed/gen_inputs.py and website/scripts/export-data.py
are plain Python: these tests run them on small synthetic data and on the real result files in the repo.
"""
import contextlib
import csv
import importlib.util
import io
import json
import sys
import tempfile
import unittest
import xml.dom.minidom
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[2]


def load(name, relative):
    spec = importlib.util.spec_from_file_location(name, REPO / relative)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


summarize = load("fair_summarize", "benchmarks/fair_speed/summarize.py")
gen_inputs = load("fair_gen_inputs", "benchmarks/fair_speed/gen_inputs.py")
export_data = load("export_data", "website/scripts/export-data.py")

FIELDS = ["file", "chunk", "callbacks", "engine", "status", "median_ms", "checksum", "note"]


def write_tsv(path, rows):
    with open(path, "w", encoding="utf-8", newline="") as target:
        writer = csv.DictWriter(target, fieldnames=FIELDS, delimiter="\t")
        writer.writeheader()
        for row in rows:
            writer.writerow({k: row.get(k, "") for k in FIELDS})


def row(file, chunk, cb, engine, ms, checksum="c1", status="1", note=""):
    return {"file": file, "chunk": chunk, "callbacks": cb, "engine": engine, "status": status,
            "median_ms": ms, "checksum": checksum, "note": note}


SAMPLE = [
    row("a.xml", "0", "1", "xpact", "20", "c1"), row("a.xml", "0", "1", "expat", "2", "c1"),
    row("a.xml", "1", "1", "xpact", "90", "c1"), row("a.xml", "1", "1", "expat", "3", "c2"),  # checksum differs
    row("a.xml", "0", "0", "xpact", "10"), row("a.xml", "0", "0", "expat", "5"),
    row("b.xml", "0", "1", "xpact", "", status="timeout", note="10 s"), row("b.xml", "0", "1", "expat", "4"),
    row("a.xml", "0", "1", "assertions", "60"),
    row("c.xml", "0", "1", "xpact", "7"),  # no Expat row: not compared
]


class SummarizeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.tsv = Path(self.tmp.name) / "results.tsv"
        write_tsv(self.tsv, SAMPLE)
        self.cell = summarize.read_cells(self.tsv)

    def test_read_cells_groups_by_file_chunk_callbacks(self):
        self.assertEqual(set(self.cell[("a.xml", "0", "1")]), {"xpact", "expat", "assertions"})

    def test_compare_ratios_mismatches_and_problems(self):
        ratios, mismatch, problems = summarize.compare(self.cell)
        self.assertAlmostEqual(ratios[("a.xml", "0", "1")], 10.0)
        self.assertAlmostEqual(ratios[("a.xml", "1", "1")], 30.0)
        self.assertEqual(mismatch, [("a.xml", "1", "1")])
        # Checksums only count with callbacks on.
        self.assertNotIn(("a.xml", "0", "0"), mismatch)
        self.assertEqual(problems, [(("b.xml", "0", "1"), "timeout", "10 s", "1")])
        self.assertNotIn(("c.xml", "0", "1"), ratios)

    def test_ratio_cell_ratio_then_status_then_empty(self):
        ratios, _, _ = summarize.compare(self.cell)
        self.assertEqual(summarize.ratio_cell(self.cell, ratios, ("a.xml", "0", "1")), "10.00")
        self.assertEqual(summarize.ratio_cell(self.cell, ratios, ("b.xml", "0", "1")), "timeout")
        self.assertEqual(summarize.ratio_cell(self.cell, ratios, ("z.xml", "0", "1")), "")

    def test_tables(self):
        ratios, _, _ = summarize.compare(self.cell)
        files = ["a.xml", "b.xml"]
        lines = summarize.ratio_tables(self.cell, ratios, files)
        self.assertIn("\n## Callbacks off\n", lines)
        self.assertIn("\n## Callbacks on\n", lines)
        self.assertTrue(any(line.startswith("| `a` | 10.00 |") for line in lines))
        absolute = summarize.absolute_table(self.cell, files)
        self.assertIn("| `a` | 20 | 2 | 90 | 3 |", absolute)
        self.assertIn("| `b` | timeout | 4 |  |  |", absolute)
        assertions = summarize.assertions_table(self.cell)
        self.assertIn("| `a` | whole | 60 | 20 | 3.0 |", assertions)
        self.assertEqual(summarize.assertions_table({}), [])

    def test_main_writes_summary(self):
        out = Path(self.tmp.name) / "summary.md"
        with mock.patch.object(sys, "argv", ["summarize.py", str(self.tsv), str(out)]), \
                contextlib.redirect_stdout(io.StringIO()):
            summarize.main()
        text = out.read_text(encoding="utf-8")
        self.assertIn("**Cells measured:** 3", text)
        self.assertIn("checksum mismatches 1", text)
        self.assertIn("## Not compared or different", text)
        self.assertIn("- checksum differs: `('a.xml', '1', '1')`", text)

    def test_real_results_have_no_checksum_mismatch(self):
        real = REPO / "student" / "results" / "fair-speed-2026-11-10" / "results.tsv"
        ratios, mismatch, _ = summarize.compare(summarize.read_cells(real))
        self.assertGreater(len(ratios), 100)
        self.assertEqual(mismatch, [])


class GenInputsTests(unittest.TestCase):
    SHAPES = ("elements", "attributes", "text", "dtd", "namespaces")

    def test_every_shape_is_well_formed_and_under_the_size(self):
        for shape in self.SHAPES:
            with self.subTest(shape=shape):
                doc = gen_inputs.document(shape, 3_000)
                self.assertLessEqual(len(doc.encode("utf-8")), 3_000)
                xml.dom.minidom.parseString(doc.encode("utf-8"))  # raises if not well-formed

    def test_records_are_deterministic(self):
        self.assertEqual(gen_inputs.record("elements", 5), gen_inputs.record("elements", 5))
        self.assertIn('id="5"', gen_inputs.record("elements", 5))
        with self.assertRaises(ValueError):
            gen_inputs.record("unknown", 0)

    def test_main_writes_all_inputs(self):
        with tempfile.TemporaryDirectory() as tmp, \
                mock.patch.object(gen_inputs, "SIZES", {"2KB": 2_000, "4KB": 4_000, "1MB": 6_000}), \
                mock.patch.object(sys, "argv", ["gen_inputs.py", tmp]), \
                contextlib.redirect_stdout(io.StringIO()):
            gen_inputs.main()
            names = sorted(p.name for p in Path(tmp).glob("*.xml"))
            self.assertEqual(len(names), 5 * 3 + 2)
            self.assertIn("elements-1MB-utf16.xml", names)
            self.assertTrue((Path(tmp) / "elements-1MB-utf16.xml").read_bytes().startswith(b"\xff\xfe"))
            latin = (Path(tmp) / "elements-1MB-latin1.xml").read_bytes()
            self.assertIn(b'encoding="ISO-8859-1"', latin)
            self.assertIn("é".encode("latin-1"), latin)


class ExportDataTests(unittest.TestCase):
    def test_helpers(self):
        self.assertEqual(export_data.fmt(1234567), "1,234,567")
        self.assertTrue(export_data.link(REPO / "README.md").endswith("/incremental-test/README.md"))

    def test_each_export_reads_the_real_reports(self):
        for name in ("conformance", "benchmarks", "comparison", "testing"):
            with self.subTest(name=name):
                data = getattr(export_data, name)()
                self.assertIsInstance(data, dict)
                self.assertTrue(json.dumps(data))

    def test_main_writes_four_json_files(self):
        # Inside the repo: main() prints each path relative to the repository.
        with tempfile.TemporaryDirectory(dir=REPO / "website") as tmp:
            data = Path(tmp) / "data"
            with mock.patch.object(export_data, "DATA", data), contextlib.redirect_stdout(io.StringIO()):
                export_data.main()
            self.assertEqual(sorted(p.name for p in data.glob("*.json")),
                             ["benchmarks.json", "comparison.json", "conformance.json", "testing.json"])


if __name__ == "__main__":
    unittest.main()
