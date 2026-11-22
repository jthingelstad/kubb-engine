"""One case of tools/mjref in MuJoCo, step by step at our engine's step (1/240 s): each
body's speed along +y and turn about x at the end of each 1/240 s window, and the normal
impulse (N s) every pair of pieces passed in it (mj_contactForce summed over the window).
The same print as `lua5.4 tools/columnprobe.lua --trace <id>` gives for our engine
(0.18, kubb on kubb).

  python3 tools/mjref/chainlog.py build/mjcol <case id> [--variant ref] [--steps 40] [--z]
  (--z: each body's height and vertical speed too; --variant hard is calibrated here if the
  run did not include it)
"""
import json
import os
import sys

import mujoco
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mjsim  # noqa: E402


def main():
    out, cid = sys.argv[1], sys.argv[2]
    var, steps, show_z = "ref", 40, False
    a = sys.argv[3:]
    while a:
        if a[0] == "--variant":
            var = a[1]
            a = a[2:]
        elif a[0] == "--steps":
            steps = int(a[1])
            a = a[2:]
        elif a[0] == "--z":
            show_z = True
            a = a[1:]
        else:
            raise SystemExit("unknown option " + a[0])
    if var not in mjsim.VARIANTS:
        mjsim.VARIANTS[var] = mjsim.EXTRA[var]
    params = json.load(open(os.path.join(out, "params.json")))
    mjsim.init(params)
    case = next(c for c in json.load(open(os.path.join(out, "cases.json"))) if c["id"] == cid)
    calib = json.load(open(os.path.join(out, "calib.json")))["dampratio"]
    if var not in calib:
        keys = sorted({"%.6g" % s["e"] for s in params["surfaces"].values()})
        calib[var] = {}
        for e in keys:
            calib[var][e] = mjsim.calibrate_one((var, float(e), False))[2]
        pe = params["world"]["pairE"]
        calib[var]["%.6g" % pe] = mjsim.calibrate_one((var, pe, True))[2]
    m = mujoco.MjModel.from_xml_string(mjsim.build(case, var, calib))
    d = mujoco.MjData(m)
    mjsim.set_state(m, d, case)
    dt = mjsim.VARIANTS[var]["dt"]
    per = int(round((1 / 240) / dt))
    ids = [b["id"] for b in case["bodies"]]
    gid = {mujoco.mj_name2id(m, mujoco.mjtObj.mjOBJ_GEOM, "g_" + i): i for i in ids}
    f6 = np.zeros(6)
    print("%s (%s): per 1/240 s, each body's vy (m/s) and wx (rad/s), then the pairs' normal impulse (N s)" % (cid, var))
    for s in range(1, steps + 1):
        imp = {}
        for _ in range(per):
            mujoco.mj_step(m, d)
            for k in range(d.ncon):
                c = d.contact[k]
                g1, g2 = gid.get(c.geom1), gid.get(c.geom2)
                if g1 is None or g2 is None:
                    continue
                mujoco.mj_contactForce(m, d, k, f6)
                a_, b_ = sorted((g1, g2), key=ids.index)
                key = a_ + "-" + b_
                imp[key] = imp.get(key, 0.0) + f6[0] * dt
        line = ["%3d" % s]
        for k, i in enumerate(ids):
            vadr = m.jnt_dofadr[k]
            R = d.xmat[k + 1].reshape(3, 3)
            w = R @ d.qvel[vadr + 3:vadr + 6]
            line.append("%s %+5.2f %+6.1f" % (i, d.qvel[vadr + 1], w[0]))
            if show_z:
                line.append("z %.4f vz %+.2f" % (d.qpos[m.jnt_qposadr[k] + 2], d.qvel[vadr + 2]))
        for key in sorted(imp):
            if imp[key] > 1e-4:
                line.append("%s %.3f" % (key, imp[key]))
        print("  ".join(line))


if __name__ == "__main__":
    main()
