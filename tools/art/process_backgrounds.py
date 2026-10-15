#!/usr/bin/env python3
"""Resize opaque backgrounds/tiles and crop the platform strip for runtime use."""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

raw = Path(sys.argv[1])
out = Path("assets/template/game/env")
out.mkdir(parents=True, exist_ok=True)


def save(im: Image.Image, name: str, lossless=False, q=86):
    im.save(out / name, "WEBP", lossless=lossless, quality=q, method=6)
    print(name, im.size)


far = Image.open(raw / "bg_far.png").convert("RGB")
save(far.resize((2016, 864), Image.LANCZOS), "bg_far.webp", q=84)

mid = Image.open(raw / "bg_mid.png").convert("RGBA")
a = np.array(mid)[..., 3]
rows = np.nonzero(a.max(axis=1) > 30)[0]
top = max(0, rows.min() - 4)
mid = mid.crop((0, top, mid.width, mid.height))
w = 2016
mid = mid.resize((w, round(mid.height * w / mid.width)), Image.LANCZOS)
save(mid, "bg_mid.webp", q=88)

ground = Image.open(raw / "ground_tile.png").convert("RGB")
save(ground.resize((512, 512), Image.LANCZOS), "ground.webp", q=86)

plat = Image.open(raw / "platform_strip.png").convert("RGBA")
a = np.array(plat)[..., 3]
rows = np.nonzero(a.max(axis=1) > 40)[0]
plat = plat.crop((0, rows.min(), plat.width, rows.max() + 1))
h = 80
plat = plat.resize((round(plat.width * h / plat.height), h), Image.LANCZOS)
save(plat, "platform.webp", lossless=True)

title = Image.open(raw / "title_art.png").convert("RGB")
save(title.resize((1920, 1080), Image.LANCZOS), "title_art.webp", q=88)
