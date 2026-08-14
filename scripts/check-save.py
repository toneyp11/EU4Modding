#!/usr/bin/env python3
"""Scan an EU4 save for structures that cause the STACK_OVERFLOW name-recursion crash.

EU4 builds a country's display name by walking relationship links (overlord /
colonial_parent). If those links ever form a CYCLE, name resolution recurses forever
and the game dies with EXCEPTION_STACK_OVERFLOW in RtlCreateUnicodeString (~3700
identical frames - a true infinite loop, not deep data).

This script parses a save and reports:
  * cycles in the overlord graph and the colonial_parent graph   <- the smoking gun
  * deepest chains in each graph (near-cycles / unusual nesting)
  * colonial nations whose parent is itself a subject/colonial nation
  * countries carrying override_country_name (dynamic names, another recursion source)
  * AutomationTools state (atools_* hub variables) for context

Usage:  python scripts/check-save.py "<path to .eu4>"
Saves must be UNCOMPRESSED text (EU4txt). Ironman/compressed saves won't parse.
"""
import io
import os
import re
import sys


def load(path):
    with io.open(path, encoding="latin-1", errors="ignore") as fh:
        return fh.read()


def find_cycle(edges):
    """edges: child -> parent. Return a cycle as a list, or None."""
    colour = {}   # 0 = visiting, 1 = done
    for start in edges:
        if colour.get(start):
            continue
        path, node = [], start
        while node in edges and colour.get(node) != 1:
            if node in path:                       # revisited within this walk
                return path[path.index(node):] + [node]
            path.append(node)
            colour[node] = 0
            node = edges[node]
        for n in path:
            colour[n] = 1
    return None


def depth(edges, node, limit=10000):
    seen, d = set(), 0
    while node in edges and d < limit:
        if node in seen:
            return -1                              # cycle
        seen.add(node)
        node = edges[node]
        d += 1
    return d


def main(path):
    txt = load(path)
    if not txt.startswith("EU4txt"):
        print("WARNING: not an uncompressed EU4txt save - results may be empty.\n")

    date = re.search(r"^date=([0-9.]+)", txt, re.M)
    print(f"save   : {os.path.basename(path)}")
    print(f"date   : {date.group(1) if date else '?'}")

    # --- AutomationTools context -------------------------------------------------
    atools = sorted(set(re.findall(r"(atools_[a-z_]+)=([0-9.]+)", txt)))
    if atools:
        print("atools : " + ", ".join(f"{k}={v}" for k, v in atools))

    # --- Relationship graphs -----------------------------------------------------
    # Inside `countries={`, each country is a 1-tab block: \tTAG={ ... } with its
    # fields at 2 tabs (overlord="XXX", colonial_parent="XXX").
    cstart = txt.find("\ncountries={")
    body = txt[cstart:] if cstart >= 0 else txt
    hdr = re.compile(r"\n\t([A-Z0-9-]{3})=\{")
    spans = [(m.group(1), m.end()) for m in hdr.finditer(body)]
    print(f"tags   : {len(spans)} country blocks")

    graphs = {"overlord": {}, "colonial_parent": {}}
    last_top = []
    for i, (tag, start) in enumerate(spans):
        end = spans[i + 1][1] if i + 1 < len(spans) else len(body)
        seg = body[start:end]
        for field, edges in graphs.items():
            f = re.search(r"\n\t\t" + field + r'="?([A-Z0-9-]{3})"?', seg)
            if f and f.group(1) != tag:
                edges[tag] = f.group(1)
        if "atools_last_top" in seg:          # diagnostic flag set by the shrink tool
            last_top.append(tag)
    if last_top:
        print(f"#1 tag : {', '.join(last_top)}   <- last nation the shrink tool acted on")

    problems = 0
    for field, edges in graphs.items():
        print(f"\n== {field} graph ==  ({len(edges)} links)")
        if not edges:
            print("   (none)")
            continue
        cyc = find_cycle(edges)
        if cyc:
            problems += 1
            print(f"   *** CYCLE FOUND: {' -> '.join(cyc)}  <== CRASH CAUSE ***")
        else:
            print("   OK  no cycle")
        deepest = sorted(((depth(edges, n), n) for n in edges), reverse=True)[:5]
        print("   deepest chains: " + ", ".join(f"{n}({d})" for d, n in deepest))

    # Colonial nation whose parent is itself a subject (nested colonial parentage).
    ov, cp = graphs["overlord"], graphs["colonial_parent"]
    nested = [t for t, p in cp.items() if p in cp or p in ov]
    if nested:
        print(f"\n!! colonial nations whose parent is itself a subject/colonial: {nested}")
        print("   (nested colonial parentage - a step away from a name-resolution cycle)")

    # --- Dynamic names -----------------------------------------------------------
    ocn = re.findall(r'override_country_name="?([A-Za-z0-9_]+)"?', txt)
    print(f"\n== override_country_name ==  ({len(ocn)} countries)")
    if ocn:
        for k in sorted(set(ocn)):
            print(f"   {k}")
        print("   (a name key whose loc value resolves back to the country recurses forever)")

    print("\nRESULT: " + ("PROBLEM FOUND (see *** above)" if problems else "no name-cycle detected"))
    return 1 if problems else 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1]))
