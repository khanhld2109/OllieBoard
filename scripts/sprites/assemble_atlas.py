#!/usr/bin/env python3
"""Pack four native RGBA 8x4 atlases into OllieBoard's 8x16 sheet.

This preserves generated colour/alpha and frame order. It does not run Gemini
chroma-keying, watermark masking, skin grading, frame repair, or resampling.
"""
import argparse
import json
from pathlib import Path
import shutil

import numpy as np
from PIL import Image

from gen_prompts import CHARACTERS, ROWS


def component_groups(alpha):
    """Label connected alpha runs, then associate each sprite with its grid slot."""
    height, width = alpha.shape
    parents = [0]
    labels = np.zeros(alpha.shape, dtype=np.int32)
    runs = []
    previous = []

    def root(label):
        while parents[label] != label:
            parents[label] = parents[parents[label]]
            label = parents[label]
        return label

    for y in range(height):
        # Very faint antialias pixels must not join two neighboring drawings.
        edges = np.diff(np.pad((alpha[y] > 8).astype(np.int8), (1, 1)))
        current = []
        previous_index = 0
        for left, right in zip(np.flatnonzero(edges == 1), np.flatnonzero(edges == -1)):
            label = len(parents)
            parents.append(label)
            while previous_index < len(previous) and previous[previous_index][1] < left:
                previous_index += 1
            for old_left, old_right, old_label in previous[previous_index:]:
                if old_left > right:
                    break
                parents[root(old_label)] = root(label)
            labels[y, left:right] = label
            current.append((left, right, label))
            runs.append((y, left, right, label))
        previous = current
    roots = np.array([root(i) for i in range(len(parents))])
    bounds = {}
    for y, left, right, label in runs:
        key = int(roots[label])
        box = bounds.setdefault(key, [left, y, right, y + 1])
        box[0], box[1] = min(box[0], left), min(box[1], y)
        box[2], box[3] = max(box[2], right), max(box[3], y + 1)
    mapping = np.full(len(parents), -1, dtype=np.int32)
    for label, (left, top, right, bottom) in bounds.items():
        if right - left > width / 8 * 1.6 or bottom - top > height / 4 * 1.6:
            raise ValueError("Adjacent sprites touch or overlap; regenerate with transparent gaps")
        column = min(7, int((left + right) / 2 / (width / 8)))
        row = min(3, int((top + bottom) / 2 / (height / 4)))
        mapping[label] = row * 8 + column
    groups = mapping[roots[labels]]
    # Assign soft alpha fringes to a nearby core without grading their colour
    # or opacity. Isolated nearly invisible specks remain unassigned.
    for _ in range(3):
        missing = (groups < 0) & (alpha > 0)
        if not missing.any():
            break
        padded = np.pad(groups, 1, constant_values=-1)
        for neighbor in (padded[:-2, 1:-1], padded[2:, 1:-1], padded[1:-1, :-2], padded[1:-1, 2:]):
            take = missing & (neighbor >= 0)
            groups[take] = neighbor[take]
            missing[take] = False
    return groups


def unpack(path):
    image = Image.open(path)
    if image.mode != "RGBA":
        raise ValueError(f"{path}: expected RGBA with native transparency")
    rgba = np.asarray(image)
    alpha = rgba[..., 3]
    if float((alpha == 0).mean()) < 0.1:
        raise ValueError(f"{path}: expected a transparent background")
    visible = alpha > 32
    if any(edge.sum() > 3 for edge in (visible[0], visible[-1], visible[:, 0], visible[:, -1])):
        raise ValueError(f"{path}: artwork touches the outer canvas edge; regenerate it")
    groups = component_groups(alpha)
    x_pitch, y_pitch = image.width / 8, image.height / 4
    padding = round(max(x_pitch, y_pitch) * 0.35)
    frames = []
    for row in range(4):
        line = []
        for column in range(8):
            mask = groups == row * 8 + column
            if (mask & visible).sum() < x_pitch * y_pitch * 0.04:
                raise ValueError(f"{path}: missing/incomplete character in cell {row},{column}")
            yy, xx = np.nonzero(mask)
            left, top, right, bottom = xx.min(), yy.min(), xx.max() + 1, yy.max() + 1
            crop = rgba[top:bottom, left:right].copy()
            crop[~mask[top:bottom, left:right], 3] = 0
            cell = Image.new("RGBA", (round(x_pitch) + 2 * padding, round(y_pitch) + 2 * padding))
            cell.alpha_composite(Image.fromarray(crop),
                                 (round(left - column * x_pitch) + padding,
                                  round(top - row * y_pitch) + padding))
            line.append(cell)
        frames.append(line)
    return frames, min(x_pitch, y_pitch)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("id", choices=sorted(CHARACTERS))
    parser.add_argument("atlases", nargs=4, type=Path, help="RGBA 8x4 atlases, rows 0-3, 4-7, 8-11, 12-15")
    parser.add_argument("--install", action="store_true")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    out = repo / "build" / "sprites" / args.id
    sheet = Image.new("RGBA", (2048, 4096))
    report = []
    bundles = [unpack(path) for path in args.atlases]
    # Normalize each atlas from an upright resting pose, then use the same
    # character height everywhere. Never shrink just one action frame.
    reference_slots = [(0, range(4)), (3, range(2)), (1, range(4)), (1, range(4))]
    body_heights = []
    for (frames, _), (row, columns) in zip(bundles, reference_slots):
        boxes = [frames[row][column].getbbox() for column in columns]
        body_heights.append(float(np.median([box[3] - box[1] for box in boxes])))
    normalized_size = 220.0
    for group, (frames, _) in enumerate(bundles):
        pitch = body_heights[group]
        for local_row, line in enumerate(frames):
            count = ROWS[group * 4 + local_row][1]
            boxes = [cell.getbbox() for cell in line[:count]]
            span = max(box[3] for box in boxes) - min(box[1] for box in boxes)
            width = max(box[2] - box[0] for box in boxes)
            normalized_size = min(normalized_size, 240 * pitch / span, 248 * pitch / width)
    for group, (frames, _) in enumerate(bundles):
        scale = normalized_size / body_heights[group]
        for local_row, line in enumerate(frames):
            row = group * 4 + local_row
            name, count, _ = ROWS[row]
            used = line[:count]
            boxes = [cell.getbbox() for cell in used]
            ground = max(box[3] for box in boxes)
            for column, (cell, box) in enumerate(zip(used, boxes)):
                crop = cell.crop(box)
                width, height = round(crop.width * scale), round(crop.height * scale)
                lift = max(0, round((ground - box[3]) * scale))
                left, top = 128 - width // 2, 244 - height - lift
                if width > 256 or top < 0:
                    raise ValueError(f"row {row} frame {column}: pose does not fit; regenerate at consistent scale")
                crop = crop.resize((width, height), Image.Resampling.LANCZOS)
                sheet.alpha_composite(crop, (column * 256 + left, row * 256 + top))
            report.append({"row": row, "animation": name, "frames": count})
    out.mkdir(parents=True, exist_ok=True)
    target = out / f"{args.id}.png"
    sheet.save(target)
    preview = Image.new("RGBA", sheet.size, (35, 39, 48, 255))
    preview.alpha_composite(sheet)
    preview.resize((1024, 2048), Image.Resampling.LANCZOS).convert("RGB").save(out / f"{args.id}-preview.png")
    (out / "atlas-report.json").write_text(json.dumps(report, indent=2) + "\n")
    for group, path in enumerate(args.atlases):
        dest = out / f"atlas-{group + 1}.png"
        if path.resolve() != dest.resolve():
            shutil.copyfile(path, dest)
    if args.install:
        sprites = repo / "Sources" / "OllieBoard" / "Resources" / "Sprites"
        generator = repo / "Sources" / "SpriteGen" / "main.swift"
        if "custom-sheets.txt" not in generator.read_text():
            raise ValueError("SpriteGen must preserve custom-sheets.txt before installation")
        listing = sprites / "custom-sheets.txt"
        previous = listing.read_text() if listing.exists() else ""
        ids = {line.strip() for line in previous.splitlines() if not line.lstrip().startswith("#")}
        if args.id not in ids:
            prefix = previous + ("\n" if previous and not previous.endswith("\n") else "")
            listing.write_text(prefix + args.id + "\n")
        shutil.copyfile(target, sprites / target.name)
    print(f"Wrote {target}; 16 animation rows, original frame order and RGBA preserved")


if __name__ == "__main__":
    main()
