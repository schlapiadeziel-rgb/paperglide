#!/usr/bin/env python3
"""Convert a glow sheet painted on pure black into straight-alpha RGBA.

alpha = max(R,G,B) (after a small black-point lift), colour = rgb / alpha, so
the sprite composites identically under additive blending and looks right
with normal blending over dark areas.
usage: black_to_alpha.py in.png out.png [--black 10]
"""
import sys
import numpy as np
from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
black = int(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[3] == "--black" else 10
rgb = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
m = rgb.max(axis=2)
a = np.clip((m - black) / (255.0 - black), 0.0, 1.0)
safe = np.maximum(a, 1e-4)[..., None]
col = np.clip(rgb / 255.0 / safe, 0.0, 1.0)
col = np.where(a[..., None] > 0.004, col, 0.0)
out = np.dstack([col * 255.0, a * 255.0]).astype(np.uint8)
Image.fromarray(out, "RGBA").save(dst)
print("wrote", dst)
