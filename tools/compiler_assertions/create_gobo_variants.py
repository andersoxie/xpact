#!/usr/bin/env python3
"""Copy audited Gobo 26.10 benchmark C output into diagnostic-only variants.

This does not run a compiler or modify the input or installed runtime. The
generated build scripts retain their original toolchain paths. Build and time
the copies separately; none of these variants belongs in production benchmarks.
"""

import argparse
import difflib
import hashlib
import json
from pathlib import Path
import re
import shutil


BOXING_EXPRESSION = "(GE_unqualified(ac, T111f11(ac, C, GE_boxed111(ac, *C))))"
BOX_FUNCTION = re.compile(r"T0\* GE_boxed(_pointer)?(\d+)\([^\n]+\)\n\{\n")
COUNTER_SUPPORT = r'''#include <stdio.h>
#include <stdlib.h>
static unsigned long long xp_diag_boxes[@SIZE@];
static unsigned long long xp_diag_pointer_boxes[@SIZE@];
static unsigned long long xp_diag_all_boxes;
static unsigned long long xp_diag_integer_invariant_count;
static void xp_diag_report_counts(void)
{
    unsigned int i;
    fprintf(stderr, "XPACT_DIAGNOSTIC boxed_integer_32=%llu integer_32_invariants=%llu\n",
        xp_diag_boxes[111], xp_diag_integer_invariant_count);
    for (i = 0; i < @SIZE@; ++i) {
        if (xp_diag_boxes[i] || xp_diag_pointer_boxes[i])
            fprintf(stderr, "XPACT_BOXES type_id=%u value_boxes=%llu pointer_boxes=%llu\n",
                i, xp_diag_boxes[i], xp_diag_pointer_boxes[i]);
    }
}
static void xp_diag_note_box(unsigned int id, int pointer)
{
    if (xp_diag_all_boxes++ == 0) atexit(xp_diag_report_counts);
    if (pointer) ++xp_diag_pointer_boxes[id]; else ++xp_diag_boxes[id];
}

'''


def feature_text(source, start_marker, end_marker):
    if source.count(start_marker) != 1 or source.count(end_marker) != 1:
        raise ValueError("Unsupported generated source: expected unique " + start_marker)
    start = source.index(start_marker)
    end = source.index(end_marker, start)
    return source[start:end]


def source_variants(source):
    invariant = feature_text(source, "/* INTEGER_32.invariant */", "/* INTEGER_32.abs */")
    conformance = feature_text(source, "/* INTEGER_32.conforms_to */", "/* INTEGER_32.min */")
    if invariant.count(BOXING_EXPRESSION) != 1 or "void T111inv(" not in invariant:
        raise ValueError("Unsupported generated INTEGER_32 invariant; expected audited boxing expression")
    if "/* Body */\n\t{\n\tR = EIF_TRUE;\n\t}" not in conformance:
        raise ValueError("INTEGER_32.conforms_to is not the audited constant-true implementation")
    gate = "if (!(ac->in_assertion)) {\n"
    if invariant.count(gate) != 1:
        raise ValueError("Unsupported INTEGER_32 invariant assertion gate")
    boxes = list(BOX_FUNCTION.finditer(source))
    if not boxes or not any(match.group(2) == "111" for match in boxes):
        raise ValueError("Missing expected boxing function definitions")
    array_size = max(int(match.group(2)) for match in boxes) + 1
    counted = source[:boxes[0].start()] + COUNTER_SUPPORT.replace("@SIZE@", str(array_size)) + source[boxes[0].start():]

    def inject_counter(match):
        return match.group(0) + "\txp_diag_note_box({}, {});\n".format(
            int(match.group(2)), int(bool(match.group(1))))

    counted = BOX_FUNCTION.sub(inject_counter, counted)
    counted_invariant = invariant.replace(gate, gate + "\t\t++xp_diag_integer_invariant_count;\n", 1)
    counted = counted.replace(invariant, counted_invariant, 1)
    unboxed = source.replace(invariant, invariant.replace(BOXING_EXPRESSION, "EIF_TRUE", 1), 1)
    return {"counts": counted, "no-integer-box": unboxed}


def create_variants(generated_dir, output_dir):
    generated_dir = generated_dir.resolve(strict=True)
    output_dir = output_dir.resolve()
    if (generated_dir == output_dir or generated_dir in output_dir.parents
            or output_dir in generated_dir.parents):
        raise ValueError("Input and output directories must be separate, non-nested directories")
    if output_dir.exists() and (not output_dir.is_dir() or any(output_dir.iterdir())):
        raise ValueError("Output directory must be new or empty; existing diagnostics are not overwritten")
    inputs = sorted(path for path in generated_dir.iterdir()
                    if path.is_file() and path.suffix in (".c", ".h", ".sh"))
    scripts = [path for path in inputs if path.suffix == ".sh"]
    candidates = [path for path in inputs if path.suffix == ".c"
                  and "/* INTEGER_32.invariant */" in path.read_text(encoding="utf-8")]
    if len(scripts) != 1 or len(candidates) != 1 or not any(path.suffix == ".h" for path in inputs):
        raise ValueError("Expected one build script, generated headers, and one INTEGER_32 implementation")
    source_path, script_path = candidates[0], scripts[0]
    source = source_path.read_text(encoding="utf-8")
    script = script_path.read_text(encoding="utf-8")
    variants = source_variants(source)
    o3_script, replacements = re.subn(r"(?<!\S)-O2(?!\S)", "-O3", script)
    if not replacements:
        raise ValueError("Expected -O2 in the original build script")
    modifications = {
        "counts": (source_path, source, variants["counts"]),
        "no-integer-box": (source_path, source, variants["no-integer-box"]),
        "o3": (script_path, script, o3_script),
    }
    output_dir.mkdir(parents=True, exist_ok=True)
    metadata = {
        "generated_dir": str(generated_dir),
        "input_sha256": {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in inputs},
        "variants": {},
    }
    for name, (changed_path, before, after) in modifications.items():
        destination = output_dir / name
        destination.mkdir()
        for path in inputs:
            shutil.copyfile(path, destination / path.name)
        (destination / changed_path.name).write_text(after, encoding="utf-8", newline="\n")
        (destination / "source.diff").write_text("".join(difflib.unified_diff(
            before.splitlines(keepends=True), after.splitlines(keepends=True),
            fromfile="original/" + changed_path.name, tofile=name + "/" + changed_path.name)),
            encoding="utf-8")
        metadata["variants"][name] = {
            "changed_file": changed_path.name,
            "modified_sha256": hashlib.sha256(after.encode()).hexdigest(),
        }
    (output_dir / "variants.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    return metadata


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--generated-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        result = create_variants(args.generated_dir, args.output_dir)
    except (OSError, ValueError) as error:
        parser.exit(1, "Cannot create diagnostic variants: {}\n".format(error))
    print("Created diagnostic copies: " + ", ".join(result["variants"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
