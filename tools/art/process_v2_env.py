#!/usr/bin/env python3
"""v2 environments: stage 2/3 parallax layers + ground tiles, the title logo,
the loading-screen key art and share art. Stage-only files are written under
assets/template/game/stage2|stage3 so the Web export can move them into segment packs."""
import sys
from pathlib import Path
import numpy as np
from PIL import Image

raw = Path(sys.argv[1])


def save(im: Image.Image, path: str, lossless=False, q=86):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    im.save(p, "WEBP", lossless=lossless, quality=q, method=6)
    print(path, im.size)


def far(name, out):
    im = Image.open(raw / f"{name}.png").convert("RGB")
    save(im.resize((2016, 864), Image.LANCZOS), out, q=82)


def mid(name, out):
    im = Image.open(raw / f"{name}.png").convert("RGBA")
    a = np.array(im)[..., 3]
    rows = np.nonzero(a.max(axis=1) > 30)[0]
    im = im.crop((0, max(0, rows.min() - 4), im.width, im.height))
    w = 2016
    save(im.resize((w, round(im.height * w / im.width)), Image.LANCZOS), out, q=86)


def ground(name, out):
    im = Image.open(raw / f"{name}.png").convert("RGB")
    # force horizontal seamlessness: cross-fade the outer 8% with the mirrored edge
    arr = np.asarray(im.resize((512, 512), Image.LANCZOS)).astype(np.float32)
    w = arr.shape[1]
    band = 40
    left = arr[:, :band].copy()
    right = arr[:, w - band:].copy()
    for i in range(band):
        t = i / band
        blend = right[:, i] * (1 - t) + left[:, i] * t
        arr[:, w - band + i] = right[:, i] * (1 - t) + left[:, i] * t if False else arr[:, w - band + i]
    # simple approach: roll by half and blend seam region
    rolled = np.roll(arr, w // 2, axis=1)
    mix = arr.copy()
    x = np.arange(w)
    wgt = np.clip(1 - np.abs(x - w / 2) / band, 0, 1)[None, :, None]
    mix = rolled * (1 - wgt) + np.roll(arr, 0, axis=1) * wgt
    save(Image.fromarray(np.clip(np.roll(mix, -w // 2, axis=1), 0, 255).astype(np.uint8)), out, q=86)


far("canyon_far", "assets/template/game/stage2/bg_far.webp")
mid("canyon_mid", "assets/template/game/stage2/bg_mid.webp")
ground("ground_canyon", "assets/template/game/stage2/ground.webp")
far("fortress_far", "assets/template/game/stage3/bg_far.webp")
mid("fortress_mid", "assets/template/game/stage3/bg_mid.webp")
ground("ground_fortress", "assets/template/game/stage3/ground.webp")

logo = Image.open(raw / "logo.png").convert("RGBA")
a = np.array(logo)[..., 3]
ys, xs = np.nonzero(a > 20)
logo = logo.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
logo = logo.resize((1100, round(logo.height * 1100 / logo.width)), Image.LANCZOS)
save(logo, "assets/template/game/ui/logo.webp", q=92)

# loading-screen key art for the HTML shell (not a Godot resource)
lb = Image.open(raw / "loading_bg.png").convert("RGB").resize((1600, 900), Image.LANCZOS)
Path("web").mkdir(exist_ok=True)
pass  # loading bg now produced by tools/art/process_share.py
pass
