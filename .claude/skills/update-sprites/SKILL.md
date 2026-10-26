---
name: update-sprites
description: Redraw an OllieBoard character's sprite sheet with Gemini-generated art (Gemini web app driven through Claude in Chrome), assemble the images into the 8x16 sheet, fix the skin colour, install it and test it in the app. Use when asked to update, redraw or replace a character's sprite (e.g. "update the sprite for luffy"). For a brand-new character use the add-character skill, which calls this one for the art.
---

# Redraw a character's sprite with Gemini + Claude in Chrome

The sheets in `Sources/OllieBoard/Resources/Sprites/<id>.png` are normally drawn by code (`Sources/SpriteGen`). This skill replaces one sheet with AI-generated art. `assemble.py --install` also lists the id in `Sprites/custom-sheets.txt`, which SpriteGen (`make sprites` / `make app`) reads and leaves alone; without that line every `make app` would redraw the sheet from code and lose the new art.

## Sheet format (what the app expects)
- 2048x4096 px PNG, 8 columns x 16 rows of 256x256 px cells, transparent background, character faces RIGHT, feet at (128, 244) px in each cell (`layout.json` anchor 64,122 pt). A smaller sheet crashes the app when the character loads (SpriteSheet.swift:95).
- Rows (frames): 0 idle 4, 1 walk 8, 2 run 6, 3 kick 7, 4 carry 8, 5 happy 6, 6 bored 4, 7 yawn 8, 8 sleep 4, 9 grumpy 4, 10 dragged 4, 11 surprised 2, 12 work 4, 13 sad 4, 14 skill1 8, 15 skill2 8. Agent mascots (claude, codex, gemini, opencode, cursor, aider) only use rows 0-13.
- What the rows show in the game (the prompts already say this): `carry` is both arms straight up holding NOTHING (the app puts a desktop icon there), `dragged` is lifted by both hands with arms straight up and legs dangling (not by the scruff), `work` sits with a laptop on the lap.
- Skill rows play 8 frames in 1 second and `Pet.swift` `skillPlan` times hits and effects to frame numbers (e.g. Luffy's fist lands on frame 5, Cat Knight's shield on frame 4, Zenitsu draws on frame 5). The character table in `gen_prompts.py` states these frames in each skill prompt; check them in the preview. Effects drawn by the game at runtime (Trump's wall, Xi's tanks, Frieren's closed chest, flames, coins...) must not be drawn into the row.
- `layout.json` and `effects.png` are shared by all characters; do not touch them.

## Prerequisites (check with the user)
- Chrome with the Claude in Chrome extension, signed in to gemini.google.com with image generation.
- Chrome's download location set to the `raw/` folder printed in step 1 (Settings -> Downloads -> Location), or files land in ~/Downloads and must be moved. Remind the user to restore it afterwards.
- `python3 -m venv .venv && .venv/bin/pip install -r scripts/sprites/requirements.txt` (once; Claude may run this).
- The user (and the repo owner) accept AI-generated art for this character: Gemini's style is a shaded cartoon, not the flat chibi look of the code-drawn sprites. Politician caricatures (trump, putin, xi, kim): Gemini may refuse real people; if it does, stop and keep the code-drawn sheet, do not try to get around it.

## Steps
1. **Prompts.** `.venv/bin/python scripts/sprites/gen_prompts.py <id>` writes `build/sprites/<id>/chrome-task.md` (instructions for Chrome + one model-sheet prompt + one prompt per row) and creates `build/sprites/<id>/raw/`. `--list` shows known ids. Designs that exist only in this game (`ORIGINAL`: Cat Knight and the mascots) get `<id>_reference.png`, cut from the current sheet, attached to the model-sheet prompt; `--reference picture.png` attaches your own picture instead.
2. **Generate.** Either the user pastes the whole `chrome-task.md` into Claude in Chrome, or Claude drives Chrome itself with the Claude in Chrome tools (ask which browser, and ask once before downloading the images). Rules either way:
   - One Gemini chat per character; model sheet first, then each row prompt on its own, waiting until the image is fully drawn (no stop button, not grey).
   - **Never use Gemini's "Download full size" button.** Tested on Zoro: it returned blurry, ghosted or half-grey upscales, sometimes of a different generation than the one on screen. Save the picture displayed in the chat with the canvas snippet in `chrome-task.md` (it is 1024 px wide; earlier answers still in the page can be saved the same way).
   - Look at each image before saving; one picture per row name, never the same picture under two names.
3. **Assemble and check.** `.venv/bin/python scripts/sprites/assemble.py <id>`.
   - Every raw strip is checked first. **Rejected** strips (left empty): unfinished grey placeholder, the same picture as another row, heavy ghosting / motion blur, < 100 px per frame, far fewer frames than asked. The log ends with a ready `gen_prompts.py <id> --rows ...` command.
   - **View `build/sprites/<id>/raw-contact.png`** (all raw strips with their verdicts): the checks cannot see a wrong animation in the right file (e.g. a sitting pose saved as `dragged`) or one blurry face.
   - Log notes: `count differs, resampled` (frames picked evenly; for skill rows check the action frame did not move), `EQUAL SPLIT - check`, `replaced bad frames [..]` (cut/broken frames swapped for the nearest good one), `MISSING`.
   - **Skin colour.** Gemini draws skin darker and honey-yellow (Luffy #F1BC8F, Zoro #F5C19B) while the game's skin is a pale peach #FFEBDE (own tones for Cat Knight, Putin, Trump in `GAME_SKIN`). The script finds the character's main skin colour and moves colours of that hue towards the game's tone, keeping shading, outlines, hair, clothes and blush. `--skin` sets the strength: default 0.6 (keeps a light tan; the user's choice on Zoro), 0.9 = nearly the game's pale peach (judged too pale), 0 = off. It is off by default for Cat Knight (`NO_SKIN_FILTER`, her fur would be bleached). The log prints `skin: Gemini #.. -> game #..`.
   - Rows are scaled to one character height (sitting rows 87%, as in the code-drawn sheets) and jumps keep their height above the ground.
   - **Look at `build/sprites/<id>/<id>-preview.png`**: no cut frames, no dark bars, feet on one line, similar size across rows, skill action on the expected frames.
4. **Redo bad rows.** `gen_prompts.py <id> --rows 2,5,9` writes a task for just those rows in the same Gemini chat. Save them, run step 3 again (the newest file for a row wins).
5. **Install and test.** `assemble.py <id> --install` (refuses while rows are missing; mascots need rows 0-13 only; adds the id to `custom-sheets.txt`), then `swift build -c release --product OllieBoard`. Run only this character without touching the user's installed app: `defaults write OllieBoard enabledCharacters -array <id>` and start `$(swift build -c release --show-bin-path)/OllieBoard`. Characters kick real Desktop icons: tell the user macOS may ask for Finder access (deny it to only watch). Claude usually cannot screenshot other apps' windows, so ask the user to check: standing, walking, click (happy), 4 quick clicks (grumpy), drag, right-click both skills. When done: kill that process and `defaults delete OllieBoard enabledCharacters`.

## Known limits
- The automatic checks catch gross errors only; always look at `raw-contact.png` and the preview.
- A few frames (about 5 of 90 on Zoro) can come out cut at a cell edge when Gemini draws a sword or arm across a cell border; redo that row if it matters.
- Gemini ignores frame counts (resampled) and the 8-frame rows are about 128 px per frame, so they are slightly soft at 256 px.
- The skin filter is hue-based: things with a skin-like hue (a straw hat, wood) shift slightly, and it cannot tell a deliberately tanned character from Gemini's cast; lower `--skin` or add the tone to `GAME_SKIN`.
- Props change the measured height (a big aura or a raised object makes that row's character a bit smaller).
- The Gemini API has no free tier for image models; this workflow uses the Gemini web app.
- `swift run SpriteGen` currently crashes on macOS 15 with a CoreGraphics assertion while drawing the sheets after Eren (seen with the unmodified code too), so `make app` fails there; that is unrelated to these scripts.

## Files
- `scripts/sprites/gen_prompts.py`: character table (looks and skill rows as SpriteGen draws them) + prompt/task generator.
- `scripts/sprites/assemble.py`: raw strips -> checked, colour-corrected sheet (+ preview, contact sheet, `--install`).
- `Sources/OllieBoard/Resources/Sprites/custom-sheets.txt`: ids SpriteGen must not redraw.
- Work output: `build/sprites/<id>/` (git-ignored).
