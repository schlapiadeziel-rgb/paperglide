#!/usr/bin/env python3
"""v2 share art: OG card (1200x630), favicon (512 PNG, rounded-corner alpha) and
the loading-shell key art (assets/template/share/loading_bg.webp, staged by
web/export.json). Original generated sources are supplied via ART_RAW_V2."""
import os
from pathlib import Path

from PIL import Image, ImageDraw

RAW = Path(os.environ["ART_RAW_V2"])
root = Path(__file__).resolve().parents[2]
share = root / "assets/template/share"
share.mkdir(parents=True, exist_ok=True)

# OG: 16:9 source -> 1.905:1, keep the logo (left) and hero; trim top/bottom evenly.
og = Image.open(RAW / "og_card.png").convert("RGB")
w, h = og.size
th = int(w / (1200 / 630))
top = (h - th) // 2
og = og.crop((0, top, w, top + th)).resize((1200, 630), Image.LANCZOS)
og.save(share / "og.png", optimize=True)

# Favicon: 512px with rounded-corner transparency.
fv = Image.open(RAW / "favicon.png").convert("RGBA").resize((512, 512), Image.LANCZOS)
mask = Image.new("L", (512, 512), 0)
ImageDraw.Draw(mask).rounded_rectangle((6, 6, 506, 506), radius=92, fill=255)
fv.putalpha(mask)
fv.save(share / "favicon.png", optimize=True)

# Loading key art (source may be the generated PNG or the earlier webp copy).
src = RAW / "loading_bg.png"
lb = Image.open(src).convert("RGB")
lb = lb.resize((1600, int(1600 * lb.size[1] / lb.size[0])), Image.LANCZOS)
lb.save(share / "loading_bg.webp", "WEBP", quality=80, method=6)
for f in ("og.png", "favicon.png", "loading_bg.webp"):
    p = share / f
    print(f, Image.open(p).size, p.stat().st_size)
