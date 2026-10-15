#!/usr/bin/env python3
"""Measure attachment points (muzzle, claw, hands) on hero frames, in display units relative to the pivot."""
import json
from pathlib import Path

import numpy as np
from PIL import Image


def load(sheet, name):
    meta = json.loads(Path(f"assets/template/game/sprites/{sheet}/frames.json").read_text())["frames"][name]
    a = np.array(Image.open(f"assets/template/game/sprites/{sheet}/{meta['file']}"))[..., 3] > 60
    return a, meta["pivot"]


def rightmost(a, y0f, y1f):
    h = a.shape[0]
    band = a[int(h * y0f):int(h * y1f)]
    ys, xs = np.nonzero(band)
    i = xs.argmax()
    return xs[i], ys[i] + int(h * y0f)


def topmost(a):
    ys, xs = np.nonzero(a)
    i = ys.argmin()
    return xs[i], ys[i]


out = {}
for sheet, name, mode in [
    ("hero", "idle", "right"), ("hero", "idle2", "right"), ("hero", "crouch", "right"), ("hero", "jump", "right"),
    ("hero", "grapple", "right"), ("hero", "slash", "right"), ("hero", "throw", "right"),
    ("hero", "aim_up", "top"), ("hero", "carry", "top"),
] + [("hero_run", f"run{i}", "right") for i in range(8)]:
    a, (px, py) = load(sheet, name)
    if mode == "right":
        x, y = rightmost(a, 0.15, 0.6)
    else:
        x, y = topmost(a)
    out[f"{sheet}/{name}"] = (round((x - px) / 2, 1), round((y - py) / 2, 1))
# aim_down: lowest opaque pixel of the gun column band (right side of pivot, above the knees)
a, (px, py) = load("hero", "aim_down")
h, w = a.shape
cols = a[: int(h * 0.75), int(px):]
ys, xs = np.nonzero(cols)
i = ys.argmax()
out["hero/aim_down"] = (round((xs[i]) / 2, 1), round((ys[i] - py) / 2, 1))
for k, v in out.items():
    print(k, v)
