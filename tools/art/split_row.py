#!/usr/bin/env python3
"""Split a single-row sheet whose items' glows touch, using column gaps at a
high alpha threshold. Writes <out>/<name>.webp + frames.json (centre pivots),
scaled so the tallest item is --height px.
usage: split_row.py sheet.png out_dir names_csv --height 220 [--thr 140]"""
import argparse
import json
from pathlib import Path
import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("sheet"); ap.add_argument("out"); ap.add_argument("names")
ap.add_argument("--height", type=int, default=220); ap.add_argument("--thr", type=int, default=140)
a = ap.parse_args()
names = a.names.split(",")
im = Image.open(a.sheet).convert("RGBA")
arr = np.asarray(im)
solid = arr[..., 3] > a.thr
cols = solid.sum(axis=0)
occupied = cols > 2
segs, start = [], None
for x, v in enumerate(occupied):
    if v and start is None:
        start = x
    elif not v and start is not None:
        segs.append([start, x]); start = None
if start is not None:
    segs.append([start, len(occupied)])
segs = [s for s in segs if s[1] - s[0] > 20]
while len(segs) > len(names):  # merge the narrowest gap
    gaps = [segs[i + 1][0] - segs[i][1] for i in range(len(segs) - 1)]
    i = int(np.argmin(gaps)); segs[i][1] = segs[i + 1][1]; del segs[i + 1]
assert len(segs) == len(names), (len(segs), segs)
# cut boundaries halfway between items, include faint glow
bounds = [0] + [(segs[i][1] + segs[i + 1][0]) // 2 for i in range(len(segs) - 1)] + [im.width]
crops = []
for i in range(len(names)):
    c = im.crop((bounds[i], 0, bounds[i + 1], im.height))
    bb = c.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    crops.append(c.crop(bb))
scale = a.height / max(c.height for c in crops)
out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
frames = {}
for n, c in zip(names, crops):
    c = c.resize((max(1, round(c.width * scale)), max(1, round(c.height * scale))), Image.LANCZOS)
    c.save(out / f"{n}.webp", "WEBP", lossless=True)
    frames[n] = {"file": f"{n}.webp", "pivot": [c.width // 2, c.height // 2]}
    print(n, c.size)
(out / "frames.json").write_text(json.dumps({"frames": frames}, indent=1))
