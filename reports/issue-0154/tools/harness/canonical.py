"""James Clark canonical XML (the W3C suite's OUTPUT files) from an engine event list.

First form: no XML declaration, no comments, CDATA as text, attributes sorted,
every element written as start + end tag, PIs as <?target data?>.
Second form (used when notations are declared): a DOCTYPE with the sorted notations.
"""
ESCAPES = {"&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "\t": "&#9;", "\n": "&#10;", "\r": "&#13;"}


def esc(text):
    return "".join(ESCAPES.get(ch, ch) for ch in text)


def canonical(events):
    out, notations, root, doctype_at = [], {}, None, 0
    for ev in events:
        kind = ev[0]
        if kind == "start":
            if root is None:
                root = ev[1]
            pairs = sorted(zip(ev[2][0::2], ev[2][1::2]))
            out.append("<" + ev[1] + "".join(f' {k}="{esc(v)}"' for k, v in pairs) + ">")
        elif kind == "end":
            out.append(f"</{ev[1]}>")
        elif kind == "chars":
            out.append(esc(ev[1]))
        elif kind == "pi":
            out.append(f"<?{ev[1]} {ev[2]}?>")
        elif kind == "startdoctype" and root is None:
            root = ev[1]
        elif kind == "enddoctype":
            doctype_at = len(out)  # the DOCTYPE goes after PIs from the internal subset
        elif kind == "notationdecl":
            name, system, public = ev[1], ev[2], ev[3]
            if public and system:
                notations[name] = f"<!NOTATION {name} PUBLIC '{public}' '{system}'>"
            elif public:
                notations[name] = f"<!NOTATION {name} PUBLIC '{public}'>"
            else:
                notations[name] = f"<!NOTATION {name} SYSTEM '{system}'>"
    if notations:
        out.insert(doctype_at, f"<!DOCTYPE {root} [\n" + "".join(notations[k] + "\n" for k in sorted(notations)) + "]>\n")
    return "".join(out)
