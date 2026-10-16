#!/usr/bin/env python3
"""Lists string literals in Dart files that look like English shown to people
but are not sent through .tr / .td / .trArgs / .tdArgs. A helper for
translating the app; it over-reports (ids, keys, formats), so judge each line.

Usage: python3 tool/untranslated.py lib/ui/screens/settings_screen.dart ...
"""
import re
import sys

LIT = re.compile(r"""(r?)'((?:\\.|[^'\\\n])*)'|(r?)"((?:\\.|[^"\\\n])*)\"""")
CALL = re.compile(r"\s*\.(tr|td|trArgs|tdArgs|inLang)\b")
SKIP_LINE = re.compile(r"^\s*(import|export|part|//|///|@)")
WORDS = re.compile(r"[A-Za-z]{2,}")


def scan(path):
    src = open(path, encoding="utf-8").read()
    lines = src.split("\n")
    pos = 0
    out = []
    for m in LIT.finditer(src):
        if m.start() < pos:
            continue
        # group adjacent literals
        end = m.end()
        parts = [m.group(2) if m.group(2) is not None else m.group(4)]
        while True:
            n = LIT.match(src, len(src[:end]) + (len(src[end:]) - len(src[end:].lstrip())))
            if not n:
                break
            parts.append(n.group(2) if n.group(2) is not None else n.group(4))
            end = n.end()
        pos = end
        text = "".join(parts)
        line_no = src.count("\n", 0, m.start()) + 1
        line = lines[line_no - 1]
        if SKIP_LINE.match(line):
            continue
        if CALL.match(src, end):
            continue
        plain = re.sub(r"\$\{[^}]*\}|\$\w+", "", text)
        if not WORDS.search(plain):
            continue
        if re.fullmatch(r"[a-z0-9_./:-]+", plain):  # ids, keys, paths
            continue
        if re.fullmatch(r"[A-Za-z]+[A-Z][A-Za-z]*", plain) and " " not in plain:
            continue  # camelCase identifiers
        out.append((line_no, text))
    return out


if __name__ == "__main__":
    total = 0
    for p in sys.argv[1:]:
        for ln, t in scan(p):
            total += 1
            print(f"{p}:{ln}: {t}")
    print(f"-- {total} candidates", file=sys.stderr)
