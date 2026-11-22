"""The drive into a group (0.16.0) in both engines: tools/mjref's drive cases
(cases.lua cases.drive, export.lua --cases drive), read from ours.jsonl and
mj.jsonl with compare.py's own toppled() and summed per setting. A single throw
into a group is chaotic, so the cases are compared as distributions, not one by
one: field kubbs felled per baton, the share felling two or more and none, and
where the baton came to rest beyond the group's back kubb.

  python3 tools/mjref/drive.py build/mjdrive
"""
import json
import os
import sys
from collections import defaultdict

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compare import Trace, load, toppled  # noqa: E402


def outcome(case, rec, P):
    tr = Trace(rec, P)
    ids = rec["ids"]
    K = P["kinds"]
    felled = 0
    for fid in case["extra"]["field"]:
        k = ids.index(fid)
        if toppled(tr.body(k), K["kubb"]):
            felled += 1
    b = tr.body(ids.index("baton"))
    return felled, float(b[-1, 1] - case["extra"]["backY"])


def energy(a, k):
    """Each sample's kinetic energy (J) of a body: translation and rotation."""
    m = k["mass"]
    I = np.array(k["inertia"], dtype=float)
    w_, x, y, z = a[:, 3], a[:, 4], a[:, 5], a[:, 6]
    # world angular velocity into the body frame: R^T w
    R = np.stack([
        np.stack([1 - 2 * (y * y + z * z), 2 * (x * y - w_ * z), 2 * (x * z + w_ * y)], axis=1),
        np.stack([2 * (x * y + w_ * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w_ * x)], axis=1),
        np.stack([2 * (x * z - w_ * y), 2 * (y * z + w_ * x), 1 - 2 * (x * x + y * y)], axis=1)], axis=1)
    wb = np.einsum("nji,nj->ni", R, a[:, 10:13])
    return 0.5 * m * (a[:, 7:10] ** 2).sum(axis=1) + 0.5 * (I * wb ** 2).sum(axis=1)


def chain(case, rec, P):
    """A struck column: each kubb's peak kinetic energy and peak momentum along the
    throw, whether it toppled, and the baton's speed along the throw 0.1 s after its
    first touch of the front kubb against its speed before."""
    tr = Trace(rec, P)
    ids = rec["ids"]
    K = P["kinds"]
    out = []
    for fid in case["extra"]["field"]:
        a = tr.body(ids.index(fid))
        out.append((float(energy(a, K["kubb"]).max()), float((K["kubb"]["mass"] * a[:, 8]).max()),
                    toppled(a, K["kubb"])))
    b = tr.body(ids.index("baton"))
    v0 = case["bodies"][-1]["vel"][1]
    k1 = tr.body(ids.index(case["extra"]["field"][0]))
    moved = np.nonzero(np.linalg.norm(k1[:, 7:10], axis=1) > 0.02)[0]
    i = int(moved[0]) if len(moved) else 0
    j = min(len(b) - 1, i + int(round(0.1 / tr.dt)))
    return out, float(b[j, 8] / v0)


def main():
    out = sys.argv[1]
    P = json.load(open(os.path.join(out, "params.json")))
    cases = json.load(open(os.path.join(out, "cases.json")))
    ours = load(os.path.join(out, "ours.jsonl"), "mode")
    mj = load(os.path.join(out, "mj.jsonl"), "variant")
    variants = sorted({v for (_, v) in mj})
    cols = ["mech", "game"] + variants
    agg = defaultdict(lambda: defaultdict(list))
    chains = [c for c in cases if c["id"].startswith("drive-chain")]
    if chains:
        print("a struck column: peak energy (J) and momentum (N s) of each kubb, front first, toppled (x), baton speed kept 0.1 s on")
        for c in chains:
            print(c["group"])
            for col in cols:
                rec = ours.get((c["id"], col)) or mj.get((c["id"], col))
                if rec is None or "error" in rec:
                    continue
                ks, kept = chain(c, rec, P)
                print("  %-6s E %s  p %s  fell %s  baton %+.2f" % (
                    col, " ".join("%.3f" % k[0] for k in ks), " ".join("%.2f" % k[1] for k in ks),
                    "".join("x" if k[2] else "." for k in ks), kept))
        print()
    for c in cases:
        if c["id"].startswith("drive-chain"):
            continue
        for col in cols:
            rec = ours.get((c["id"], col)) or mj.get((c["id"], col))
            if rec is None or "error" in rec:
                continue
            agg[c["group"]][col].append(outcome(c, rec, P))
    print("setting           engine  n   kubbs   2+    0   baton past the back kubb (m, median)")
    for g in sorted(agg):
        for col in cols:
            xs = agg[g][col]
            if not xs:
                continue
            f = np.array([x[0] for x in xs])
            y = np.array([x[1] for x in xs])
            print("%-17s %-6s %3d   %4.2f  %3.0f%%  %3.0f%%   %+5.2f" % (
                g, col, len(xs), f.mean(), 100 * (f >= 2).mean(), 100 * (f == 0).mean(), float(np.median(y))))
        print()


if __name__ == "__main__":
    main()
