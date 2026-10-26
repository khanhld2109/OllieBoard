---
name: add-character
description: Add a brand-new character to OllieBoard: code (Characters.swift, its two special moves in Pet.swift, dialogue in English/Vietnamese/Japanese, skill names, README) plus an AI-generated sprite sheet made with the update-sprites workflow. Use when asked to add, create or make a new character / new pet (e.g. "add Naruto", "tạo nhân vật mới").
---

# Add a new character

A character is an id (lowercase, e.g. `naruto`) that ties together a sprite sheet `Sources/OllieBoard/Resources/Sprites/<id>.png`, an entry in `allCharacters`, two special moves and dialogue in 3 languages. Do the code and the art in this order, building after each part.

## 0. Agree on the design with the user first
Ask for, or propose and confirm:
- id, display name, series (existing `Series` case or a new one), whether it is an existing anime character (Gemini can look it up) or an original design (needs a reference picture).
- Appearance in one line (hair, eyes, outfit and colours, props).
- Personality: walk speed, how often it kicks / arranges icons / sleeps / is social (`weights`), shy, prankster, grumpy or sad when annoyed.
- Two special moves: a name, what the sprite row shows frame by frame (8 frames, 1 second), on which frame the action lands, and what the game adds at runtime (blast icons, an effect from PetWindow.swift, friends reacting...).
- Do not copy dialogue from the anime verbatim; write short original lines in the character's spirit.

## 1. Code (all paths under Sources/OllieBoard/)
1. `Characters.swift`
   - `enum Skill` (around line 8): add two cases with a comment, e.g. `case rasengan, shadowClone // Naruto`.
   - `enum Series` (around line 38): add a case only for a new series (its raw value is the menu title; new series get their own submenu automatically).
   - `allCharacters` (around line 85): add a `Character(...)`. Copy a similar character and change id, name, series, walkSpeed, `weights` (must include `.skill` or the moves never fire on their own), grumpyAnim, shy, prankster, `skills: [.a, .b]`. Array order = menu order.
2. `Dialogue.swift`: add a `Line` case for each move (and extra steps if a move talks twice), and `.<move>: ["<id>"]` in `Line.skillSpeakers`. Optionally add the id to `.cheer` / `.thought`.
3. `Dialogue+English.swift`, `Dialogue+Vietnamese.swift`, `Dialogue+Japanese.swift`: add a `"<id>": Lines(shortName:, lines:[...], pairGreet:)` entry (Cat Knight's entry is the template: it has every key: .happy .bored .tedious .grumpy .kick .arrange .click .poke .wake .noIcons .fail .done .greet .greetBack .wakeOther .hit .sorry .pranked .chased .comfort .thanks .together + the move lines). `%@` = partner's name, `{app}` = frontmost app. Add both move names to `englishSkillNames` / `vietnameseSkillNames` / `japaneseSkillNames` at the bottom of each file.
4. `Pet.swift` `skillPlan(_:)` (around line 673) is an exhaustive switch with no default: each new move needs a `case`, or the build fails. Simplest form: `case .rasengan: return engage([.play(.skill1, 1, say: .rasengan), .play(.happy, 1, effect: .sparkle)])`. Richer moves: copy `.gomuPistol` or `.knightOath` / `.shieldBash`; building blocks are `.play/.hold/.line/.walk/.face/.run { }`, `blastAhead`, `blastAround`, `dash`, `nearbyFriends` + `friend.receive(...)`, and PetView effects in `PetWindow.swift` (puff, aura, slash, lightning, beam, shockwave, domain, impact, showProp, ...). Time each hit to the frame where the row shows it (8 fps: frame 5 ends at 0.625 s).
5. Do **not** add a `Look` in `Sources/SpriteGen/Looks.swift`: the sheet comes from Gemini, and SpriteGen never writes an id it has no Look for. New props for `effects.png` need a SpriteGen `drawEffect` + `Effect` case; avoid that unless necessary.
6. `README.md`: add the character to the feature list (Cat Knight's bullet is the model).
7. `swift build -c release --product OllieBoard` must pass now. Until the sheet exists, do not enable the character (a missing sheet is a `fatalError` when it loads).

## 2. Sprite sheet (update-sprites workflow)
1. Add the character to `CHARACTERS` in `scripts/sprites/gen_prompts.py`: `"<id>": ("Full name (Series)", "<appearance>", "<skill1 row, frame by frame, action frame>", "<skill2 row ...>")`. Original design: also add the id to `ORIGINAL` and run with `--reference <picture>`.
2. Follow the update-sprites skill steps 1-4 (generate in Gemini, save the displayed images, `assemble.py <id>`, check `raw-contact.png` and the preview, redo bad rows). New characters use the default skin tone unless you add one to `GAME_SKIN` in `assemble.py`; non-human characters (fur, robots) go in `NO_SKIN_FILTER`.
3. `assemble.py <id> --install` writes the sheet and lists it in `custom-sheets.txt`.

## 3. Test
- `swift build -c release --product OllieBoard`, then `defaults write OllieBoard enabledCharacters -array <id>` and run `$(swift build -c release --show-bin-path)/OllieBoard`. Ask the user to check (Claude usually cannot see other app windows): the menu shows the character under its series in each language (Ngôn ngữ / Language / 言語), it walks and idles, click / 4 clicks / drag / right-click shows both move names and both moves play with their dialogue and effects lining up with the drawn action.
- Clean up: kill the dev process, `defaults delete OllieBoard enabledCharacters`.
- There is no test suite; `swift build` catches a missing `skillPlan` case or `Line`.

## Checklist before a PR
- [ ] Skill cases, Character entry, Line cases + skillSpeakers
- [ ] Dialogue in 3 languages + 3 skill-name tables
- [ ] `skillPlan` cases timed to the drawn frames
- [ ] Sheet 2048x4096 installed, id in `custom-sheets.txt`, no Look added
- [ ] README updated; `swift build` passes; tested in the app by the user
