#!/usr/bin/env python3
"""Slice a generated grid sprite sheet into trimmed, uniformly scaled frames.

Each connected alpha component is assigned to the grid cell containing its
centroid, so limbs that overhang a cell edge stay with their own pose. Frames
share one scale factor (from a reference frame or the median height) and each
frame records a pivot (feet anchor by default) so animation does not jitter.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("sheet", type=Path)
    p.add_argument("--cols", type=int, required=True)
    p.add_argument("--rows", type=int, required=True)
    p.add_argument("--names", required=True, help="comma separated frame names (use - to skip a cell)")
    p.add_argument("--out", type=Path, required=True)
    p.add_argument("--target-height", type=float, required=True, help="output pixel height of the scale reference")
    p.add_argument("--scale-ref", default="median", help="median | max | <frame name>")
    p.add_argument("--anchor", default="feet", choices=["feet", "center", "bottom", "torso"])
    p.add_argument("--min-area", type=int, default=250)
    p.add_argument("--alpha", type=int, default=28)
    args = p.parse_args()

    img = Image.open(args.sheet).convert("RGBA")
    arr = np.array(img)
    alpha = arr[..., 3]
    mask = alpha > args.alpha
    labels, count = ndimage.label(mask, structure=np.ones((3, 3)))
    H, W = mask.shape
    cw, ch = W / args.cols, H / args.rows
    names = [n.strip() for n in args.names.split(",")]
    assert len(names) == args.cols * args.rows, f"expected {args.cols*args.rows} names, got {len(names)}"

    objs = ndimage.find_objects(labels)
    areas = ndimage.sum(mask, labels, index=np.arange(1, count + 1))
    coms = ndimage.center_of_mass(mask, labels, index=np.arange(1, count + 1))
    cell_components: dict[int, list[int]] = {i: [] for i in range(len(names))}
    for idx in range(count):
        if areas[idx] < args.min_area:
            continue
        cy, cx = coms[idx]
        col = min(args.cols - 1, int(cx // cw))
        row = min(args.rows - 1, int(cy // ch))
        cell_components[row * args.cols + col].append(idx + 1)

    crops = {}
    for i, name in enumerate(names):
        if name == "-" or not cell_components[i]:
            if name != "-":
                print(f"WARNING: no content for {name}")
            continue
        comp_mask = np.isin(labels, cell_components[i])
        # Grow slightly so soft anti-aliased edges below the threshold survive.
        grown = ndimage.binary_dilation(comp_mask, iterations=2)
        ys, xs = np.nonzero(grown)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        piece = arr[y0:y1, x0:x1].copy()
        piece[..., 3] = np.where(grown[y0:y1, x0:x1], piece[..., 3], 0)
        crops[name] = piece

    heights = {n: c.shape[0] for n, c in crops.items()}
    if args.scale_ref == "median":
        ref_h = float(np.median(list(heights.values())))
    elif args.scale_ref == "max":
        ref_h = float(max(heights.values()))
    else:
        ref_h = float(heights[args.scale_ref])
    scale = args.target_height / ref_h

    args.out.mkdir(parents=True, exist_ok=True)
    meta = {"scale": scale, "frames": {}}
    for name, piece in crops.items():
        im = Image.fromarray(piece, "RGBA")
        w = max(1, round(im.width * scale))
        h = max(1, round(im.height * scale))
        im = im.resize((w, h), Image.LANCZOS)
        a = np.array(im)[..., 3].astype(np.float32)
        if args.anchor == "torso":
            # Head/upper torso stays steady through gait cycles; x = mass centre of
            # the upper band, y = frame bottom (feet).
            band = a[int(h * 0.08):int(h * 0.42), :]
            cols = band.sum(axis=0)
            px = float((cols * np.arange(w)).sum() / max(1.0, cols.sum()))
            py = float(h)
        elif args.anchor == "feet":
            band = a[int(h * 0.82):, :]
            cols = band.sum(axis=0)
            px = float((cols * np.arange(w)).sum() / max(1.0, cols.sum()))
            py = float(h)
        elif args.anchor == "bottom":
            px, py = w / 2.0, float(h)
        else:
            cols = a.sum(axis=0)
            rows = a.sum(axis=1)
            px = float((cols * np.arange(w)).sum() / max(1.0, cols.sum()))
            py = float((rows * np.arange(h)).sum() / max(1.0, rows.sum()))
        file = args.out / f"{name}.webp"
        im.save(file, "WEBP", lossless=True, quality=100, method=6)
        meta["frames"][name] = {"file": file.name, "size": [w, h], "pivot": [round(px, 1), round(py, 1)]}
        print(f"{name}: {w}x{h} pivot=({px:.0f},{py:.0f})")
    (args.out / "frames.json").write_text(json.dumps(meta, indent=1))


if __name__ == "__main__":
    main()
