#!/usr/bin/env python3
"""Assembles Gemini sprite strips into a game sprite sheet.

  python3 scripts/sprites/assemble.py luffy              # reads build/sprites/luffy/raw/luffy_rowN_*.png
  python3 scripts/sprites/assemble.py luffy --install    # also copies it into Sources/OllieBoard/Resources/Sprites/

Writes build/sprites/<id>/<id>.png (2048x4096: 8 columns x 16 rows of 256px cells, feet at (128,244)) and <id>-preview.png.
Each raw strip is checked first (see check_strip): a strip that is the wrong image, an unfinished grey placeholder, heavily
ghosted, too small or a copy of another row is rejected, left empty in the sheet and listed with the gen_prompts.py command
that redoes it. A contact sheet of all raw strips with their verdicts is written to raw-contact.png. --keep-bad uses them anyway.
It removes the magenta background and Gemini's corner watermark, paints over its faint cell borders, cuts each strip
into frames, brightens the skin and pulls the honey-yellow out of it (--skin), resamples to the expected frame count and swaps clearly broken frames for the nearest good one.
Needs: pip install -r scripts/sprites/requirements.txt
"""
import argparse, glob, os, re, shutil, sys
import numpy as np
from PIL import Image
from gen_prompts import CHARACTERS

CELL, COLS = 256, 8
FEET = (128, 244)
ROWS = [("idle",4),("walk",8),("run",6),("kick",7),("carry",8),("happy",6),("bored",4),("yawn",8),
        ("sleep",4),("grumpy",4),("dragged",4),("surprised",2),("work",4),("sad",4),("skill1",8),("skill2",8)]
KEY = np.array([255, 0, 255], float)
# Character height per row relative to standing, measured on the code-drawn sheets (sitting rows are ~12% shorter).
STAND_H = 228
HEIGHT = {"bored": 0.87, "sleep": 0.87, "work": 0.88}
MIN_FRAME_PX = 100                 # a strip narrower than this per frame would be upscaled into mush
GHOST_MAX = 0.10                   # share of semi-transparent pixels (motion blur / afterimages) relative to solid ones
PLACEHOLDER_MAX = 0.015            # Gemini's unfinished-image placeholder is a warm grey block, ~(160,150,140)
DUPLICATE_MIN = 0.985              # correlation above which two rows are the same picture
# Skin colour of the code-drawn sheets as rendered (measured on each sheet's flat skin fill). Gemini's skin comes out darker and
# honey-yellow (about Lab 78,12,22 against 93,6,10 here), so frames are pulled towards this.
DEFAULT_SKIN = (255, 235, 222)
GAME_SKIN = {"catknight": (255, 246, 237), "putin": (253, 233, 223), "trump": (255, 227, 203)}
# Characters whose "skin-coloured" areas are not human skin: Cat Knight's ginger and cream fur would be bleached.
NO_SKIN_FILTER = {"catknight"}
SKIN_STRENGTH = 0.6                # 0 = leave Gemini's colours alone, 1 = move skin all the way to the game's skin tone
JITTER = 6                         # px; smaller baseline differences between frames are Gemini noise, not a jump

def thin(mask, maxw=6):
    """Keep only runs of True no wider than maxw (cell border lines, not whole characters)."""
    out = np.zeros_like(mask); i = 0
    while i < len(mask):
        if mask[i]:
            j = i
            while j < len(mask) and mask[j]: j += 1
            if j - i <= maxw: out[i:j] = True
            i = j
        else: i += 1
    return out

def stray_lines(a, pm, maxw=5):
    """Leftover border pieces and magenta-blended fringe: thin purple runs next to the background.
    Purple areas that belong to the character (clothes, a purple orb) are wider, so only their outermost pixels can go."""
    bg = np.linalg.norm(a - KEY, axis=2) < 120
    out = np.zeros_like(pm)
    for y in np.nonzero(pm.any(axis=1))[0]:
        row = pm[y]
        edges = np.diff(np.concatenate(([0], row.astype(np.int8), [0])))
        for s, e in zip(np.nonzero(edges == 1)[0], np.nonzero(edges == -1)[0]):
            left_ok = s == 0 or bg[y, s - 1]
            right_ok = e == len(row) or bg[y, e]
            # thin piece floating in the background, or the 1-3 px purple fringe where an outline was blended into magenta
            if (e - s <= maxw and left_ok and right_ok) or (e - s <= 3 and (left_ok or right_ok)): out[y, s:e] = True
    return out

def key_out(img):
    """Chroma-key magenta -> RGBA with soft edges and magenta despill."""
    a = np.asarray(img.convert("RGB"), float)
    h, w = a.shape[:2]
    k = int(h*.2); a[h-k:, w-k:] = KEY          # Gemini's corner watermark (small sparkle)
    # Gemini's cell borders are dark-purple vertical lines (~110,0,95), sometimes drawn across a character.
    # Paint over them with the neighbouring columns so no hole is left in the character.
    R, G, B = a[..., 0], a[..., 1], a[..., 2]
    pm = (R > 70) & (R < 215) & (G < 45) & (np.abs(R - B) < 45)
    cols = np.convolve(thin(pm.mean(axis=0) > 0.25, 10), np.ones(5), "same") > 0
    w = a.shape[1]; x = 0
    while x < w:
        if cols[x]:
            y = x
            while y < w and cols[y]: y += 1
            left, right = max(x - 1, 0), min(y, w - 1)
            if cols[left]: left = right
            if cols[right]: right = left
            mid = (x + y) // 2
            for c in range(x, y): a[:, c] = a[:, left if c < mid else right]
            x = y
        else: x += 1
    loose = pm & ~cols[None, :]
    # vertical border pieces show up as thin runs along a row, the strip's top/bottom borders as thin runs along a column
    a[stray_lines(a, loose) | stray_lines(a.transpose(1, 0, 2), loose.T).T] = KEY
    dist = np.linalg.norm(a - KEY, axis=2)
    alpha = np.clip((dist - 70) / 90, 0, 1)
    rgb = np.where(alpha[..., None] > 0.01, (a - (1 - alpha[..., None]) * KEY) / np.maximum(alpha[..., None], 0.05), a)
    rgb = np.clip(rgb, 0, 255)
    return np.dstack([rgb, alpha * 255]).astype(np.uint8)

def placeholder_share(img):
    a = np.asarray(img.convert("RGB")).astype(int)
    R, G, B = a[..., 0], a[..., 1], a[..., 2]
    return float(((R > 135) & (R < 178) & (np.abs(R - G) <= 14) & (R - B >= 8) & (R - B <= 32)).mean())

def signature(img):
    """Small grey picture of a strip, used to spot two rows that are the same image."""
    g = np.asarray(img.convert("L").resize((96, 24), Image.BILINEAR), float).ravel()
    return (g - g.mean()) / (g.std() + 1e-6)

def check_strip(img, keyed, n, found):
    """Returns (rejections, warnings) for one raw strip."""
    bad, warn = [], []
    if placeholder_share(img) > PLACEHOLDER_MAX: bad.append("unfinished image (grey placeholder was downloaded before Gemini finished)")
    solid = float((keyed[..., 3] >= 225).mean()); semi = float(((keyed[..., 3] > 30) & (keyed[..., 3] < 225)).mean())
    if solid > 0 and semi / solid > GHOST_MAX: bad.append(f"ghosting / motion blur ({semi / solid:.2f} semi-transparent vs solid)")
    if img.width / n < MIN_FRAME_PX: bad.append(f"too small ({img.width // n} px per frame)")
    if found < max(2, n * 0.6): bad.append(f"only {found} of {n} frames found")
    elif found != n: warn.append(f"drew {found} frames instead of {n}, resampled")
    return bad, warn

_M = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
_WHITE = np.array([0.95047, 1.0, 1.08883])

def to_lab(rgb):
    a = rgb / 255.0
    a = np.where(a > 0.04045, ((a + 0.055) / 1.055) ** 2.4, a / 12.92)
    xyz = a @ _M.T / _WHITE
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)

def from_lab(lab):
    fy = (lab[..., 0] + 16) / 116
    f = np.stack([fy + lab[..., 1] / 500, fy, fy - lab[..., 2] / 200], -1)
    xyz = np.where(f ** 3 > 0.008856, f ** 3, (f - 16 / 116) / 7.787) * _WHITE
    a = xyz @ np.linalg.inv(_M).T
    a = np.where(a > 0.0031308, 1.055 * np.clip(a, 0, None) ** (1 / 2.4) - 0.055, 12.92 * a)
    return np.clip(a * 255, 0, 255)

def estimate_skin(rgba):
    """Gemini's main skin colour in Lab: the most common light, warm, not-too-saturated colour (the straw hat, hair and
    clothes fall outside this window). Returns None when there is not enough of it."""
    px = rgba[rgba[..., 3] > 240][:, :3].astype(float)
    if len(px) < 200: return None
    lab = to_lab(px)
    ang = np.degrees(np.arctan2(lab[:, 2], lab[:, 1])); chroma = np.hypot(lab[:, 1], lab[:, 2])
    m = (lab[:, 0] > 62) & (lab[:, 0] < 92) & (ang > 30) & (ang < 72) & (chroma > 9) & (chroma < 40)
    if m.sum() < 150: return None
    c = lab[m]
    hist, ea, eb = np.histogram2d(c[:, 1], c[:, 2], bins=[np.arange(0, 41, 1.5), np.arange(0, 41, 1.5)])
    i, j = np.unravel_index(hist.argmax(), hist.shape)
    near = c[(np.abs(c[:, 1] - (ea[i] + .75)) < 3.5) & (np.abs(c[:, 2] - (eb[j] + .75)) < 3.5)]
    return np.median(near, axis=0)

def grade_skin(rgba, src, dst, strength):
    """Moves colours close to Gemini's skin tone `src` (Lab) towards the game's skin tone `dst`. Pixels of other hues (straw
    hat, hair, clothes), dark outlines and the pink blush are left alone; the shading inside the skin is kept."""
    a = rgba[..., 3] > 0
    if not a.any(): return rgba
    lab = to_lab(rgba[..., :3].astype(float))
    ang = np.degrees(np.arctan2(lab[..., 2], lab[..., 1])); chroma = np.hypot(lab[..., 1], lab[..., 2])
    s_ang = np.degrees(np.arctan2(src[2], src[1])); s_c = np.hypot(src[1], src[2])
    w_h = np.clip(1 - np.abs(ang - s_ang) / 20.0, 0, 1)                       # same hue as the skin, +-20 degrees
    w_c = np.clip(np.minimum((chroma - 0.5 * s_c) / (0.25 * s_c), (1.3 * s_c - chroma) / (0.2 * s_c)), 0, 1)
    w_l = np.clip(np.minimum((lab[..., 0] - 52) / 10.0, (99 - lab[..., 0]) / 4.0), 0, 1)   # keep dark outlines, spare pure white
    w = (w_h * w_c * w_l) ** 0.7 * strength * a
    out = lab.copy()
    out[..., 0] = np.minimum(lab[..., 0] + (dst[0] - src[0]) * w, 99)
    out[..., 1] = lab[..., 1] + (dst[1] - src[1]) * w
    out[..., 2] = lab[..., 2] + (dst[2] - src[2]) * w
    res = rgba.copy(); res[..., :3] = from_lab(out).astype(np.uint8)
    return res

def pick(frames, n):
    """Gemini often draws more/fewer cells than asked: resample evenly to n frames."""
    m = len(frames)
    return [frames[round(i*(m-1)/max(n-1, 1))] for i in range(n)] if n > 1 else [frames[0]]

def split(rgba, n):
    """Cut a keyed strip into frames by the empty gaps between characters (else equal split). Returns (n frames, how, found)."""
    occ = (rgba[..., 3] > 40).any(axis=0)
    runs, start = [], None
    for x, v in enumerate(occ):
        if v and start is None: start = x
        if not v and start is not None:
            runs.append([start, x]); start = None
    if start is not None: runs.append([start, len(occ)])
    merged = []                                   # a figure that crosses a cell border got a 5px hole: stitch it back
    for r in runs:
        if merged and r[0] - merged[-1][1] <= 8: merged[-1][1] = r[1]
        else: merged.append(r)
    runs = merged
    if runs:
        med = sorted(r[1] - r[0] for r in runs)[len(runs)//2]
        runs = [r for r in runs if r[1] - r[0] > max(12, 0.4*med)]
    w = rgba.shape[1]
    if len(runs) >= 2:
        # Cut in the middle of each gap, so stray parts (a sword tip, a puff of dust) stay with their figure.
        cuts = [0] + [(runs[i - 1][1] + runs[i][0]) // 2 for i in range(1, len(runs))] + [w]
        return pick([rgba[:, cuts[i]:cuts[i + 1]] for i in range(len(runs))], n), "gaps", len(runs)
    return [rgba[:, int(i*w/n):int((i+1)*w/n)] for i in range(n)], "EQUAL SPLIT - check", n

def bbox(f):
    ys, xs = np.nonzero(f[..., 3] > 40)
    if len(xs) == 0: return None
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1

def is_bad(f, med_w):
    """A frame is bad if it is much narrower than its siblings (cut in half) or has a thin dark vertical bar through it."""
    b = bbox(f)
    if not b: return True
    x0, y0, x1, y1 = b
    if (x1 - x0) < 0.6 * med_w: return True
    sub = f[y0:y1, x0:x1]
    dark = (sub[..., :3].sum(axis=2) < 200) & (sub[..., 3] > 128)
    colf = dark.mean(axis=0)
    mask, i, n = colf > 0.55, 0, len(colf)
    while i < n:
        if mask[i]:
            j = i
            while j < n and mask[j]: j += 1
            if j - i <= 10: return True
            i = j
        else: i += 1
    return False

def repair(frames):
    """Replace bad frames with the nearest good one (previous first), keeping the timeline length."""
    widths = [bbox(f)[2] - bbox(f)[0] if bbox(f) else 0 for f in frames]
    med = sorted(widths)[len(widths)//2]
    bad = [is_bad(f, med) for f in frames]
    if all(bad) or not any(bad): return frames, [i for i, b in enumerate(bad) if b] if all(bad) else []
    out = list(frames)
    for i, b in enumerate(bad):
        if b:
            cands = sorted((j for j, bb in enumerate(bad) if not bb), key=lambda j: (abs(j - i), j > i))
            out[i] = frames[cands[0]]
    return out, [i for i, b in enumerate(bad) if b]

def write_contact(path, strips, verdict):
    """One picture of every raw strip, labelled, so a person (or Claude) can eyeball them all at once."""
    from PIL import ImageDraw
    W, rows = 1400, []
    for r in sorted(strips):
        im = Image.open(strips[r]).convert("RGB")
        im = im.resize((W, max(1, round(im.height * W / im.width))))
        if im.height > 150: im = im.resize((round(W * 150 / im.height), 150))
        bad, warn = verdict.get(r, ([], []))
        rows.append((f"row {r} {ROWS[r][0] if r < len(ROWS) else ''}: " + ("REJECTED - " + "; ".join(bad) if bad else "ok" + (" (" + "; ".join(warn) + ")" if warn else "")), im, bool(bad)))
    sheet = Image.new("RGB", (W, sum(i.height + 16 for _, i, _ in rows)), (255, 255, 255)); d = ImageDraw.Draw(sheet); y = 0
    for label, im, bad in rows:
        d.text((4, y + 2), label, fill=(200, 0, 0) if bad else (0, 90, 0)); sheet.paste(im, (0, y + 14)); y += im.height + 16
    sheet.save(path)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("id")
    ap.add_argument("src", nargs="?", help="folder with <id>_rowN_*.png (default build/sprites/<id>/raw)")
    ap.add_argument("--keep-bad", action="store_true", help="assemble rejected strips anyway (to look at them)")
    ap.add_argument("--skin", type=float, default=SKIN_STRENGTH, metavar="0-1",
                    help="brighten the skin and take the honey-yellow out of it: 0 = off, 1 = exactly the game's skin tone (default %(default)s)")
    ap.add_argument("--install", action="store_true", help="copy the sheet into Sources/OllieBoard/Resources/Sprites/")
    o = ap.parse_args()
    repo = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    src = os.path.expanduser(o.src or os.path.join(repo, "build", "sprites", o.id, "raw"))
    out = os.path.join(repo, "build", "sprites", o.id)
    os.makedirs(out, exist_ok=True)
    strips = {}                                   # row -> newest file for that row (a re-download wins over an older one)
    for f in sorted(glob.glob(os.path.join(src, "*")), key=os.path.getmtime):
        m = re.search(r"row(\d+)", os.path.basename(f))
        if m and f.lower().endswith((".png", ".jpg", ".jpeg", ".webp")): strips[int(m.group(1))] = f
    if not strips: sys.exit(f"no row images found in {src}")
    ap_rows = ROWS
    verdict, sigs = {}, {}
    for r, path in strips.items():
        if r >= len(ROWS): continue
        im = Image.open(path)
        keyed = key_out(im)
        found = split(keyed, ROWS[r][1])[2]
        verdict[r] = check_strip(im, keyed, ROWS[r][1], found)
        sigs[r] = signature(im)
    for r in sorted(sigs):
        for q in sorted(sigs):
            if q < r and r in verdict and q in verdict and float(np.dot(sigs[r], sigs[q]) / len(sigs[r])) > DUPLICATE_MIN:
                verdict[r][0].append(f"same picture as row {q} ({ROWS[q][0]}): wrong image was downloaded")
    rejected = sorted(r for r, (bad, _) in verdict.items() if bad)
    for r in sorted(verdict):
        bad, warn = verdict[r]
        for m in bad: print(f"row {r:2d} {ROWS[r][0]}: REJECTED - {m}")
        for m in warn: print(f"row {r:2d} {ROWS[r][0]}: note - {m}")
    write_contact(os.path.join(out, "raw-contact.png"), strips, verdict)
    if rejected and not o.keep_bad:
        print(f"\n{len(rejected)} strip(s) rejected: {rejected}. Redo them with:\n  .venv/bin/python scripts/sprites/gen_prompts.py {o.id} --rows {','.join(map(str, rejected))}\n"
              "(or pass --keep-bad to assemble them anyway)")
    skin_src = skin_dst = None
    if o.id in NO_SKIN_FILTER and o.skin == SKIN_STRENGTH:
        print(f"skin: off for {o.id} (fur, not skin); pass --skin to force it")
    elif o.skin > 0:
        for r in sorted(strips):                       # idle first: a standing, front-facing face gives the cleanest estimate
            if r in rejected and not o.keep_bad: continue
            skin_src = estimate_skin(key_out(Image.open(strips[r])))
            if skin_src is not None: break
        skin_dst = to_lab(np.array(GAME_SKIN.get(o.id, DEFAULT_SKIN), float))
        if skin_src is None: print("skin: no skin-coloured area found, colours left as Gemini drew them")
        else:
            sr, dr = from_lab(skin_src), from_lab(skin_dst)
            print(f"skin: Gemini #{int(sr[0]):02X}{int(sr[1]):02X}{int(sr[2]):02X} (Lab {skin_src[0]:.0f},{skin_src[1]:.0f},{skin_src[2]:.0f}) "
                  f"-> game #{int(dr[0]):02X}{int(dr[1]):02X}{int(dr[2]):02X}, strength {o.skin}")
    sheet = Image.new("RGBA", (COLS*CELL, len(ROWS)*CELL), (0, 0, 0, 0))
    # Agent mascots have no special moves, so the app never reads rows 14-15 for them.
    has_skills = CHARACTERS.get(o.id, (None, None, True, True))[2] is not None
    missing = []
    for r, (name, n) in enumerate(ROWS if has_skills else ROWS[:14]):
        if r not in strips: print(f"row {r:2d} {name}: MISSING"); missing.append(r); continue
        if r in rejected and not o.keep_bad: missing.append(r); continue
        keyed = key_out(Image.open(strips[r]))
        if skin_src is not None: keyed = grade_skin(keyed, skin_src, skin_dst, o.skin)
        frames, how, found = split(keyed, n)
        frames, replaced = repair(frames)
        boxes = [bbox(f) for f in frames]
        heights = sorted(b[3] - b[1] for b in boxes if b)
        if not heights: print(f"row {r:2d} {name}: no character found"); missing.append(r); continue
        # One scale per row, so the character has the same size in every animation whatever size Gemini drew it.
        scale = STAND_H * HEIGHT.get(name, 1.0) / heights[len(heights)//2]
        ground = max(b[3] for b in boxes if b)    # lowest feet in the strip; frames above it are jumping
        print(f"row {r:2d} {name}: wanted {n}, Gemini drew {found} ({how})" + ("  <-- count differs, resampled" if found != n else "")
              + (f"  | replaced bad frames {replaced}" if replaced else ""))
        for c, (f, b) in enumerate(zip(frames, boxes)):
            if not b: print(f"   frame {c} empty"); continue
            x0, y0, x1, y1 = b
            im = Image.fromarray(f[y0:y1, x0:x1], "RGBA")
            im = im.resize((max(1, round(im.width*scale)), max(1, round(im.height*scale))), Image.LANCZOS)
            if im.width > CELL or im.height > CELL:
                k = min(CELL/im.width, CELL/im.height); im = im.resize((int(im.width*k), int(im.height*k)), Image.LANCZOS)
                print(f"   frame {c} too big, shrunk")
            lift = round((ground - y1) * scale)
            if lift < JITTER: lift = 0
            top = FEET[1] - im.height - lift
            if top < 0: lift = max(lift + top, 0)  # keep the head inside the cell (a jump may lose a little height)
            sheet.alpha_composite(im, (c*CELL + FEET[0] - im.width//2, r*CELL + FEET[1] - im.height - lift))
    os.makedirs(out, exist_ok=True)
    sheet_path = os.path.join(out, f"{o.id}.png")
    sheet.save(sheet_path)
    prev = Image.new("RGBA", sheet.size, (40, 40, 48, 255)); prev.alpha_composite(sheet)
    prev.convert("RGB").resize((sheet.width//2, sheet.height//2)).save(os.path.join(out, f"{o.id}-preview.png"))
    print("wrote", sheet_path, "and", f"{o.id}-preview.png (look at it before installing)")
    if o.install:
        if missing:
            sys.exit(f"not installed: rows {missing} are empty, the character would vanish in those animations. Generate them first.")
        sprites = os.path.join(repo, "Sources", "OllieBoard", "Resources", "Sprites")
        dest = os.path.join(sprites, f"{o.id}.png")
        shutil.copyfile(sheet_path, dest); print("installed", dest)
        # SpriteGen (make sprites / make app) would redraw this sheet from code; listing it here makes SpriteGen leave it alone.
        listing = os.path.join(sprites, "custom-sheets.txt")
        ids = open(listing).read().split() if os.path.exists(listing) else []
        if o.id not in ids:
            with open(listing, "a") as fh:
                if not ids: fh.write("# Sheets not drawn by SpriteGen (AI-made, see scripts/sprites). SpriteGen leaves these ids alone.\n")
                fh.write(o.id + "\n")
            print(f"added {o.id} to {listing}")

if __name__ == "__main__":
    main()
