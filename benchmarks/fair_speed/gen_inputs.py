"""Generate the inputs of the fair speed test (andersoxie#275), deterministically.

Shapes (each built by repeating one record until the size is reached, then closing the root):
  elements    nested elements, little text
  attributes  empty elements with many attributes
  text        long paragraphs of text, with some non-ASCII characters
  dtd         an internal DTD with entities, and records that reference them
  namespaces  default and prefixed namespaces on elements and attributes (parse with namespaces on)
Sizes: 10 KB, 1 MB and 10 MB (10,000,000 bytes, under xpact's 10 MiB input limit).
Encodings: every shape in UTF-8; the elements shape at 1 MB also in UTF-16LE (with BOM) and ISO-8859-1.

Usage: python -I benchmarks/fair_speed/gen_inputs.py <out dir>
"""
import sys
from pathlib import Path

SIZES = {"10KB": 10_000, "1MB": 1_000_000, "10MB": 10_000_000}


def record(shape, i):
    if shape == "elements":
        return f"<item id=\"{i}\"><name>n{i}</name><group><a/><b/><c><d/></c></group><value>{i % 997}</value></item>\n"
    if shape == "attributes":
        return "<e " + " ".join(f'a{k}="v{(i * 7 + k) % 1000}"' for k in range(12)) + "/>\n"
    if shape == "text":
        return (f"<p>Paragraph {i}: the quick brown fox jumps over the lazy dog; café, naïve, Zürich, "
                f"and plain ASCII words that make up the bulk of a realistic text node in a document.</p>\n")
    if shape == "dtd":
        return f"<r n=\"{i}\">&e{i % 8}; and &e{(i + 3) % 8}; with &amp; &lt;text&gt; {i}</r>\n"
    if shape == "namespaces":
        return f"<a:item a:id=\"{i}\" b:kind=\"k{i % 5}\"><a:name>n{i}</a:name><v xmlns=\"urn:v\">{i}</v></a:item>\n"
    raise ValueError(shape)


def document(shape, size):
    head = '<?xml version="1.0" encoding="UTF-8"?>\n'
    if shape == "dtd":
        head += "<!DOCTYPE doc [\n" + "".join(f'<!ENTITY e{k} "entity {k} replacement text">\n' for k in range(8)) + "]>\n"
    root = '<doc xmlns="urn:d" xmlns:a="urn:a" xmlns:b="urn:b">\n' if shape == "namespaces" else "<doc>\n"
    parts, n, i = [head, root], len(head.encode()) + len(root.encode()) + len("</doc>\n"), 0
    while True:
        r = record(shape, i)
        rb = len(r.encode("utf-8"))
        if n + rb > size:
            break
        parts.append(r); n += rb; i += 1
    parts.append("</doc>\n")
    return "".join(parts)


def main():
    out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
    for shape in ("elements", "attributes", "text", "dtd", "namespaces"):
        for label, size in SIZES.items():
            (out / f"{shape}-{label}-utf8.xml").write_bytes(document(shape, size).encode("utf-8"))
    base = document("elements", SIZES["1MB"])
    (out / "elements-1MB-utf16.xml").write_bytes(base.replace('encoding="UTF-8"', 'encoding="UTF-16"').encode("utf-16"))
    latin = base.replace('encoding="UTF-8"', 'encoding="ISO-8859-1"').replace("<value>", "<value>é")
    (out / "elements-1MB-latin1.xml").write_bytes(latin.encode("latin-1"))
    for p in sorted(out.glob("*.xml")):
        print(f"{p.stat().st_size:>10} {p.name}")


if __name__ == "__main__":
    main()
