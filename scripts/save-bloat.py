#!/usr/bin/env python3
"""Audit an EU4 save for abnormal size / accumulation bugs.

Mod bugs that quietly append to the save (self-refiring events, per-tick variables,
flags that never get cleared) show up as OUTLIERS: one block far larger than its peers,
or a nesting depth no normal save reaches. That is how the ~1590 stack overflow was
found - the hub province had grown to 5,007,426 bytes against a 4,042-byte median, with
1,840 nested scope blocks.

Reports:
  * total size, and the size of each top-level section
  * province / country block size distribution + the biggest outliers
  * MAX NESTING DEPTH (the direct tell for a recursive structure in the save)
  * atools_* variable and flag counts (our own residue)

Usage:  python scripts/save-bloat.py "<save.eu4>" [more saves...]
Uncompressed (EU4txt) saves only.
"""
import io
import os
import re
import sys

OUTLIER_FACTOR = 20          # flag blocks this many times bigger than the median


def human(n):
    for unit in ("B", "KB", "MB", "GB"):
        if abs(n) < 1024 or unit == "GB":
            return f"{n:,.0f}{unit}" if unit == "B" else f"{n/1:,.1f}{unit}"
        n /= 1024.0


def blocks(seg, pattern, drop_last=False):
    """Return [(name, size)] for each top-level block matching pattern inside seg.

    drop_last: the final block has no following sibling to bound it, so when seg runs
    to EOF its size is inflated by everything after the section. Dropping it avoids a
    false "outlier" (this fooled an earlier run: the last country in every save looked
    ~250x the median, in an unmodded control save too).
    """
    hits = [(m.group(1), m.start()) for m in re.finditer(pattern, seg)]
    out = []
    for i, (name, s) in enumerate(hits):
        e = hits[i + 1][1] if i + 1 < len(hits) else len(seg)
        out.append((name, e - s))
    if drop_last and out:
        out = out[:-1]
    return out


def report_group(label, items):
    if not items:
        print(f"  {label}: none parsed")
        return
    sizes = sorted((sz for _, sz in items))
    median = sizes[len(sizes) // 2]
    biggest = sorted(items, key=lambda x: -x[1])[:6]
    print(f"  {label}: {len(items)} blocks, median {median:,}B, largest {biggest[0][1]:,}B")
    for name, sz in biggest:
        ratio = sz / median if median else 0
        mark = "   <== OUTLIER" if median and ratio >= OUTLIER_FACTOR else ""
        print(f"      {name:<10} {sz:>12,}B  ({ratio:>6.1f}x median){mark}")


def main(path):
    txt = io.open(path, encoding="latin-1", errors="ignore").read()
    date = re.search(r"^date=([0-9.]+)", txt, re.M)
    print("=" * 72)
    print(f"{os.path.basename(path)}   date={date.group(1) if date else '?'}   "
          f"size={len(txt)/1048576:.1f}MB")

    # --- top-level sections ---
    secs = [(m.group(1), m.start()) for m in re.finditer(r"\n([a-z_]+)=\{", txt)]
    tops = []
    for i, (name, s) in enumerate(secs):
        e = secs[i + 1][1] if i + 1 < len(secs) else len(txt)
        if e - s > 200000:
            tops.append((name, e - s))
    tops.sort(key=lambda x: -x[1])
    print("  largest top-level sections:")
    for name, sz in tops[:6]:
        print(f"      {name:<18} {sz/1048576:>8.1f}MB")

    # --- provinces (blocks are at column 0: -<id>={ ) ---
    ps, pe = txt.find("\nprovinces={"), txt.find("\ncountries={")
    if ps >= 0 and pe > ps:
        report_group("provinces", blocks(txt[ps:pe], r"\n-(\d+)=\{"))

    # --- countries (blocks are one tab in: \tTAG={ ) ---
    # Parse from "countries={" to EOF; country blocks are the only 1-tab 3-char-tag
    # blocks. drop_last because the final block runs to EOF and would otherwise look
    # like a ~250x outlier (it did, in an unmodded control save too).
    if pe >= 0:
        report_group("countries", blocks(txt[pe:], r"\n\t([A-Z0-9-]{3})=\{", drop_last=True))

    # --- max nesting depth: the direct tell for a recursive structure ---
    depth = 0
    deepest_line = 0
    for m in re.finditer(r"\n(\t+)", txt):
        d = len(m.group(1))
        if d > depth:
            depth, deepest_line = d, m.start()
    verdict = "  <== ABNORMAL (recursive structure in the save)" if depth > 40 else ""
    print(f"  max tab-nesting depth: {depth}{verdict}")
    if depth > 40:
        ctx = txt[max(0, deepest_line - 200): deepest_line + 60]
        key = re.findall(r"([a-z_]+)=\{", ctx)
        print(f"      nested key(s) at depth: {sorted(set(key)) or '(unknown)'}")

    # --- our own residue ---
    vars_ = re.findall(r"(atools_[a-z_]+)=", txt)
    from collections import Counter
    if vars_:
        print("  atools_* entries: " + ", ".join(
            f"{k}x{v}" for k, v in Counter(vars_).most_common(8)))
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    for p in sys.argv[1:]:
        main(p)
