"""expat engine for scripts/run_w3c_conformance.py (four-way comparison).

Protocol: `<engine> --conformance-file PATH [--suite-root DIR] [--namespaces]` prints
`XPACT_CONFORMANCE\tACCEPT` (exit 0) or `XPACT_CONFORMANCE\tREJECT` (exit 1); `--version` prints libexpat's version.
Non-validating. When --suite-root is given, external entities and the external DTD subset are read from inside
that folder (standard expat ExternalEntityRefHandler), like the Eiffel engines under the same profile;
`--no-external` keeps expat from reading any external file.
"""
import os
import sys
import xml.parsers.expat as expat


def verdict(path: str, namespaces: bool, root: str | None) -> bool:
    def make(namespaced_parent=None, context=None, base=path):
        p = (namespaced_parent.ExternalEntityParserCreate(context) if namespaced_parent
             else expat.ParserCreate(namespace_separator=" ") if namespaces else expat.ParserCreate())
        p.SetBase(base)
        if root:
            p.SetParamEntityParsing(expat.XML_PARAM_ENTITY_PARSING_UNLESS_STANDALONE)
            def external(ctx, ent_base, system_id, public_id):
                if not system_id:
                    return 1
                target = os.path.abspath(os.path.join(os.path.dirname(ent_base or path), system_id))
                if not target.startswith(os.path.abspath(root)) or not os.path.isfile(target):
                    return 1                      # outside the suite or missing: a non-validating processor may skip it
                child = make(p, ctx, target)
                try:
                    with open(target, "rb") as handle:
                        child.ParseFile(handle)
                    return 1
                except expat.ExpatError:
                    return 0                      # makes the parent fail: the error is inside the external entity
            p.ExternalEntityRefHandler = external
        else:
            p.SetParamEntityParsing(expat.XML_PARAM_ENTITY_PARSING_NEVER)
        return p
    try:
        with open(path, "rb") as handle:
            make().ParseFile(handle)
        return True
    except expat.ExpatError:
        return False


def main(argv: list[str]) -> int:
    if argv[1:2] == ["--version"]:
        print(expat.EXPAT_VERSION)
        return 0
    args = argv[1:]
    if len(args) < 2 or args[0] != "--conformance-file":
        print("usage: expat_conformance_engine.py --conformance-file PATH [--suite-root DIR] [--namespaces] [--no-external]", file=sys.stderr)
        return 2
    root = args[args.index("--suite-root") + 1] if "--suite-root" in args and "--no-external" not in args else None
    ok = verdict(args[1], "--namespaces" in args, root)
    print("XPACT_CONFORMANCE\t" + ("ACCEPT" if ok else "REJECT"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))