import argparse
from pathlib import Path
from xml.parsers import expat


def sample_document() -> bytes:
    parts = ["<catalog>"]
    for index in range(1, 101):
        parts.append(f'<item id="{index}">value</item>')
    parts.append("</catalog>")
    return "".join(parts).encode("utf-8")


def parse_with_callbacks(document: bytes, iterations: int) -> int:
    events = 0

    def start(_name, _attrs):
        nonlocal events
        events += 1

    def end(_name):
        nonlocal events
        events += 1

    def character_data(text):
        nonlocal events
        if text:
            events += 1

    for _ in range(iterations):
        parser = expat.ParserCreate()
        parser.StartElementHandler = start
        parser.EndElementHandler = end
        parser.CharacterDataHandler = character_data
        parser.Parse(document, True)
    return events


def parse_tokenizer_only(document: bytes, iterations: int) -> int:
    for _ in range(iterations):
        parser = expat.ParserCreate()
        parser.Parse(document, True)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--iterations", type=int, default=1000)
    parser.add_argument("--mode", choices=("callbacks", "tokenizer"), default="callbacks")
    parser.add_argument("--file", help="pre-decompressed XML document to parse")
    parser.add_argument("--version", action="store_true")
    args = parser.parse_args()

    if args.version:
        print(expat.EXPAT_VERSION)
        return 0

    if args.iterations <= 0:
        raise SystemExit("--iterations must be positive")

    document = Path(args.file).read_bytes() if args.file else sample_document()
    if args.mode == "callbacks":
        events = parse_with_callbacks(document, args.iterations)
    else:
        events = parse_tokenizer_only(document, args.iterations)
    print(
        f"libexpat pyexpat {args.mode} parsed {args.iterations} documents "
        f"({len(document)} bytes each, {events} callback events)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
