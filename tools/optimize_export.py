#!/usr/bin/env python3
"""Shrink the player export: lossy WebP import for game textures and exclude
unreferenced display fonts + the sharing-only OG image from the PCK."""
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent
n = 0
for imp in list((root / "assets/template/game/env").glob("*.import")) + list((root / "assets/template/game/sprites").rglob("*.import")):
    t = imp.read_text()
    t2 = re.sub(r"^compress/mode=\d+$", "compress/mode=1", t, flags=re.M)
    t2 = re.sub(r"^compress/lossy_quality=[\d.]+$", "compress/lossy_quality=0.85", t2, flags=re.M)
    if t2 != t:
        imp.write_text(t2)
        n += 1
print(f"lossy imports: {n}")

ep = root / "export_presets.cfg"
e = ep.read_text()
m = re.search(r'^exclude_filter="([^"]*)"$', e, flags=re.M)
items = [x for x in m.group(1).split(",") if x]
for extra in ["assets/template/fonts/display/*", "assets/template/share/og.png"]:
    if extra not in items:
        items.append(extra)
e = e[:m.start()] + 'exclude_filter="' + ",".join(items) + '"' + e[m.end():]
ep.write_text(e)
print("exclude:", ",".join(items))
