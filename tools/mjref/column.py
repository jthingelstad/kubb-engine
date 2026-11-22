"""Kubb on kubb (0.18) in both engines: tools/mjref's column cases (cases.lua
cases.column, export.lua --cases column, from tests/fixtures/contact/columns.lua), read
from ours.jsonl and mj.jsonl with compare.py's own toppled(). Per layout and strike:
kubbs toppled of all thrown at, and each kubb's mean peak kinetic energy (J), front
first, in ours ("mech": the flat ground MuJoCo models; "game": the game's grass) and in
each MuJoCo solver variant.

  python3 tools/mjref/column.py build/mjcol [--energy] [--by] [--only col6]
  (--by: each kubb's share of the throws that toppled it, front first)
"""
import json
import os
import sys
from collections import defaultdict

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compare import Trace, load, toppled  # noqa: E402
from drive import energy  # noqa: E402

ORDER = ["mech", "game", "ref", "dt2", "stiff", "soft", "hard"]


def main():
    out = sys.argv[1]
    show_e = "--energy" in sys.argv
    show_by = "--by" in sys.argv
    only = None
    if "--only" in sys.argv:
        only = sys.argv[sys.argv.index("--only") + 1]
    P = json.load(open(os.path.join(out, "params.json")))
    cases = json.load(open(os.path.join(out, "cases.json")))
    ours = load(os.path.join(out, "ours.jsonl"), "mode")
    mj = load(os.path.join(out, "mj.jsonl"), "variant")
    have = {v for (_, v) in mj} | {m for (_, m) in ours}
    cols = [c for c in ORDER if c in have]
    K = P["kinds"]["kubb"]
    agg = defaultdict(lambda: defaultdict(lambda: {"n": 0, "down": 0, "size": 0, "E": None, "by": None}))
    groups = []
    for c in cases:
        if not c["id"].startswith("col-"):
            continue
        g = c["group"]
        if only and not g.startswith(only):
            continue
        if g not in groups:
            groups.append(g)
        for col in cols:
            rec = ours.get((c["id"], col)) or mj.get((c["id"], col))
            if rec is None or "error" in rec:
                continue
            tr = Trace(rec, P)
            ids = rec["ids"]
            a = agg[g][col]
            n = len(c["extra"]["field"])
            es = np.zeros(n)
            by = np.zeros(n)
            for k, fid in enumerate(c["extra"]["field"]):
                b = tr.body(ids.index(fid))
                if toppled(b, K):
                    a["down"] += 1
                    by[k] = 1
                es[k] = energy(b, K).max()
            a["E"] = es if a["E"] is None else a["E"] + es
            a["by"] = by if a["by"] is None else a["by"] + by
            a["n"] += 1
            a["size"] = n
    print("kubbs toppled of all thrown at (and with --energy each kubb's mean peak energy, J, front first)")
    print("%-28s %s" % ("layout and strike", "  ".join("%9s" % c for c in cols)))
    tot = defaultdict(lambda: [0, 0])
    for g in groups:
        row = []
        for col in cols:
            a = agg[g][col]
            if not a["n"]:
                row.append("%9s" % "-")
                continue
            row.append("%4d/%4d" % (a["down"], a["n"] * a["size"]))
            fam = g.split(" ")[0] + " " + (g.split(" ")[1] if " " in g else "pile")
            tot[(fam, col)][0] += a["down"]
            tot[(fam, col)][1] += a["n"] * a["size"]
        print("%-28s %s" % (g, "  ".join(row)))
        if show_e or show_by:
            for col in cols:
                a = agg[g][col]
                if a["n"]:
                    parts = []
                    if show_by:
                        parts.append("toppled %s" % " ".join("%3.0f" % (100 * x) for x in a["by"] / a["n"]))
                    if show_e:
                        parts.append("E %s" % " ".join("%.3f" % e for e in a["E"] / a["n"]))
                    print("    %-6s %s" % (col, "  ".join(parts)))
    print()
    print("by layout and kind of strike (toppled share)")
    fams = sorted({f for (f, _) in tot})
    for f in fams:
        print("%-28s %s" % (f, "  ".join("%9s" % ("%.0f%%" % (100 * tot[(f, c)][0] / tot[(f, c)][1])
                                                   if tot[(f, c)][1] else "-") for c in cols)))


if __name__ == "__main__":
    main()
