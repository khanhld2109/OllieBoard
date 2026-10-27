#!/usr/bin/env python3
"""Writes the Claude-in-Chrome task (instructions + Gemini prompts) for one character.

  python3 scripts/sprites/gen_prompts.py luffy                 # model sheet + all 16 rows
  python3 scripts/sprites/gen_prompts.py luffy --rows 2,5,9    # only redo these rows (no model sheet)
  python3 scripts/sprites/gen_prompts.py --list                # known character ids
  python3 scripts/sprites/gen_prompts.py newid --reference art.png   # model sheet drawn from your own reference picture

Output: build/sprites/<id>/chrome-task.md (paste its whole content into Claude in Chrome).
Downloads must be saved in build/sprites/<id>/raw/ (created here).
To add a character, add a line to CHARACTERS below.
"""
import argparse, os, sys

# id: (name, look, skill1 row, skill2 row). skills None => agent mascot (rows 0-13 only).
# Looks and skill rows follow what SpriteGen draws today (Looks.swift, Skills.swift, SkillsAnime.swift), and the frame where the
# action lands matters: Pet.swift times hits and effects to those frames (8 frames at 8 fps = 1 second per skill row).
CHARACTERS = {
"anya": ("Anya Forger (Spy x Family)", "pink shoulder-length hair flipped outward, two black horn-shaped hair ornaments, green eyes, black Eden Academy dress",
         "mind reading: arms spread up, sparkling eyes, pink telepathy waves coming off the hair ornaments",
         "smug: hands on hips, half-lidded eyes, little smirk, a small yellow star next to her"),
"nezuko": ("Nezuko Kamado (Kimetsu no Yaiba)", "long black hair fading to orange tips, pink eyes, bamboo muzzle in her mouth, pink hemp-leaf patterned kimono, pink ribbon",
         "Exploding Blood: arms flung out wide, a ring of pink-orange flames behind her and flames in front",
         "wind-up for Exploding Blood: crouching, small flames at her feet and in her hand"),
"frieren": ("Frieren (Sousou no Frieren)", "white hair in two low twin tails with gold ties, pointed elf ears, green eyes, white mage robe, red drop earrings",
         "flower field spell: eyes closed, holding a wooden staff with a gold crescent and red gem, little stars rising",
         "Mimic: only her legs stick out upside down, kicking, from a wooden treasure chest with gold bands and teeth (the chest bites her); robe hem flared; the chest shakes"),
"bocchi": ("Hitori Gotoh (Bocchi the Rock!)", "long pink hair, blue eyes, yellow and blue cube hair clips, pink tracksuit jacket, strong blush",
         "guitar solo: playing a black Les Paul guitar with cream binding, neck pointing up behind her",
         "melt: frames 1-5 she squashes flatter and flatter into a pink puddle, frames 6-8 are a pink puddle that still shows her face and hair clips"),
"rem": ("Rem (Re:Zero)", "short blue bob, blue eyes, X-shaped hair clip, frilly white maid headdress, black and white maid dress",
         "morning star: swings a flail (handle, chain, spiked iron ball) overhead; on frames 6-8 the ball has slammed into the ground in front of her",
         "oni form: a single white horn on her forehead glowing, pale blue wisps rising around her"),
"tanjiro": ("Tanjiro Kamado (Kimetsu no Yaiba)", "dark red spiky hair, red eyes, scar on the forehead, hanafuda earrings, green and black checkered haori over a black uniform",
         "Water Breathing: swings a black-bladed katana from overhead, blue water arcs from frame 4 on",
         "Hinokami Kagura: a ring of fire flames around him and fire along the katana blade"),
"zenitsu": ("Zenitsu Agatsuma (Kimetsu no Yaiba)", "spiky yellow hair fading to orange, yellow haori with white triangles over a black uniform, katana at the hip",
         "Thunderclap and Flash: crouched low with eyes closed (asleep), hand on the sheathed sword at the hip, draws the sword from frame 5 with yellow lightning zigzags and speed lines",
         "crying for help: arms flailing up, tears streaming to both sides"),
"luffy": ("Monkey D. Luffy (One Piece)", "black messy hair, straw hat with a red band, scar under the left eye, open red vest on a bare chest, yellow sash, blue shorts, sandals",
         "Gum-Gum Pistol: the front arm stretches straight forward, longest at frame 5 (the fist lands then), then snaps back; motion lines; the fist stays inside the cell",
         "Gear Fifth: hair and clothes turn white, bouncing joyful dance, white steam clouds behind him"),
"zoro": ("Roronoa Zoro (One Piece)", "short green hair, three gold earrings in the left ear, scar over the left eye, open green coat or white shirt with a green haramaki sash, dark trousers, three katanas at the hip",
         "Three Sword Style: black bandana on his head, a katana in each hand and one in his mouth, lunges forward from frame 5 with a green slash arc",
         "Get lost: arms behind his back, looking left and right, blue question marks above him"),
"nami": ("Nami (One Piece)", "long orange hair, brown eyes, blue and white striped top, denim skirt",
         "Clima-Tact: raises a blue staff toward a small dark cloud above her, lightning strikes on frames 4-6",
         "counting money: fans out green banknotes marked with a Berry sign, sparkling eyes"),
"eren": ("Eren Yeager (Attack on Titan)", "messy brown hair, teal eyes, Survey Corps uniform: brown jacket with the Wings of Freedom, white trousers, harness straps",
         "titan shift: fist raised, titan marks under his eyes, steam puffs around him",
         "Tatakae: pumping his fist and shouting, red shout lines"),
"mikasa": ("Mikasa Ackerman (Attack on Titan)", "short black bob, grey eyes, red scarf, Survey Corps uniform with harness",
         "ODM gear: airborne and leaning forward, two blades swept back, gas puffs, grappling wires going up out of frame",
         "the scarf: pulls the red scarf up over her mouth, eyes closed, blushing"),
"levi": ("Levi Ackerman (Attack on Titan)", "black undercut with curtain bangs, grey eyes with heavy lids, white cravat, Survey Corps uniform",
         "spinning slash: his whole body turns a full 360 degrees across the 8 frames, blades out, a whirl arc",
         "cleaning: white kerchief on his head and a cloth mask, sweeping with a broom, little dust puffs"),
"yuji": ("Yuji Itadori (Jujutsu Kaisen)", "spiky pink hair with a dark undercut, marks under the eyes, navy Jujutsu High uniform with gold buttons and a red hood",
         "Divergent Fist: punches forward with a blue energy orb on the fist and a delayed ring of energy",
         "Sukuna takes over: a second pair of red eyes under his own, black face markings, evil smirk, small red stars"),
"gojo": ("Satoru Gojo (Jujutsu Kaisen)", "spiky white hair, black blindfold over the eyes, bright blue eyes when shown, dark navy uniform",
         "Domain Expansion Infinite Void: pushes the blindfold up showing sparkling blue eyes, a purple starry domain spreading behind him",
         "Hollow Purple: a blue orb and a red orb between his hands merge into one big purple orb by frame 5"),
"megumi": ("Megumi Fushiguro (Jujutsu Kaisen)", "very spiky black hair, blue-grey eyes, navy Jujutsu High uniform",
         "Divine Dogs: makes a dog hand sign over a black shadow pool, the heads of a white dog and a black dog rise from it from frame 4",
         "Rabbit Escape: white rabbit ears rising out of a black shadow pool around him"),
"gon": ("Gon Freecss (Hunter x Hunter)", "tall spiky black hair with green tips, green jacket and green shorts over a black top, green boots",
         "Jajanken: crouches while a yellow aura orb grows on his fist, then punches forward on frames 7-8",
         "fishing: sitting with a fishing rod, the line and a red bobber in a small water ripple"),
"killua": ("Killua Zoldyck (Hunter x Hunter)", "spiky white hair, blue eyes, white hoodie with purple accents, purple shoes",
         "Godspeed: crouched, crackling with blue and white lightning zigzags",
         "chocolate: holding a red Chocorobot box, munching chocolate, blushing happily"),
"kurapika": ("Kurapika (Hunter x Hunter)", "blonde bob, blue-grey eyes, blue robe with white trim",
         "Chain Jail: a chain with a dagger tip shoots straight forward from his hand",
         "Scarlet Eyes: his eyes turn bright red with a red glow, a chain dangling from his fingers"),
"catknight": ("Cat Knight (an original kitten character from this game)", "a kitten, not a human: cream fur, light ginger fur on top of the head, round ears with pink insides, fluffy fur around the face, pink nose, whiskers, a pink bow, big dark eyes, ginger tail, steel armor with pauldrons and chain mail, cream cape, always holding a long sword",
         "knight's oath: holds the sword upright in front of her face with sparkles on frames 1-4, then cuts forward on frames 6-8",
         "shield bash: pushes forward a red heater shield taller than herself (blue cross, gold stars); the shield hits on frame 4"),
"trump": ("Donald Trump as a playful chibi caricature", "blond swooping hair, blue eyes, navy suit, long red tie",
         "'huge' gesture: both arms up, two thumbs up, proud face (the wall itself is added by the game, do not draw it)",
         "tariffs: lifts a white board reading 'TARIFF 100%' with a navy header and red lines"),
"putin": ("Vladimir Putin as a playful chibi caricature", "thin receding sandy hair, small blue-grey eyes, charcoal suit, light blue shirt, purple tie",
         "judo: now in a white judo gi with a black belt, doing a throw motion, dust and a throw arc",
         "bear ride: riding a galloping brown bear, speed lines"),
"xi": ("Xi Jinping as a playful chibi caricature", "black combed-back hair, small eyes, thick brows, slightly wider build, dark suit, blue tie, red lapel pin",
         "parade: waving his hand like at a parade (the tanks are added by the game, do not draw them)",
         "Skynet robot: a chrome robot endoskeleton is built up beside him from the feet up over a red hologram grid, its red eyes light up while he points"),
"kim": ("Kim Jong Un as a playful chibi caricature", "black flat-top hair with shaved sides, slightly wider build, black suit, cream tie",
         "applause: he claps while four tiny officials around him clap too, some in tears",
         "missile: presses a launch box, a missile on an olive launcher trailer rises with smoke and flies up out of the frame"),
"claude": ("the Claude Code mascot (an original chibi girl from this game)", "orange bob hair with an orange starburst hair clip, cream hoodie, human skin", None, None),
"codex": ("the Codex mascot (an original chibi character from this game)", "dark spiky hair, glasses, dark hoodie, white shoes, human skin", None, None),
"gemini": ("the Gemini CLI mascot (an original chibi girl from this game)", "blue-to-purple hair in twin buns with a sparkle clip, navy dress, human skin", None, None),
"opencode": ("the OpenCode mascot (an original chibi character from this game)", "grey bob hair, headphones, grey hoodie with green accents, human skin", None, None),
"cursor": ("the Cursor Agent mascot (an original chibi character from this game)", "navy ponytail, cube hair clip, white hoodie, human skin", None, None),
"aider": ("the Aider mascot (an original chibi character from this game)", "brown spiky hair, beanie, green hoodie with yellow accents, human skin", None, None),
}

# (animation, frames, description). Row order == row index in the sprite sheet (see SpriteGen/main.swift).
ROWS = [
("idle",4,"standing still, gentle breathing bob, eyes blink on frame 4"),
("walk",8,"walking cycle to the right, arms and legs swinging"),
("run",6,"running to the right, leaning forward, mouth open"),
("kick",7,"angry wind-up, then the front leg kicks forward to the right, then a grin"),
("carry",8,"walking to the right with both arms raised straight up overhead and the hands open, holding NOTHING (the game places an icon there), eyes closed, wavy mouth, sweat drop"),
("happy",6,"jumping with joy, arms raised, closed happy ^^ eyes, big grin, blush"),
("bored",4,"sitting on the ground, head tilted, half-lidded bored eyes"),
("yawn",8,"standing, both arms rising overhead in a stretch while the mouth opens in a wide yawn, eyes close"),
("sleep",4,"sitting on the ground, head tilted, asleep with eyes closed"),
("grumpy",4,"angry stomping, arms down and slightly out, angry brows, pout, puffed cheek, blush"),
("dragged",4,"lifted up by both hands: both arms straight up, legs dangling and swinging, wide eyes, O mouth, sweat (NOT held by the scruff)"),
("surprised",2,"startled little hop, arms half raised, wide eyes, raised brows"),
("work",4,"sitting with a small silver laptop on the lap, typing, lid facing the viewer"),
("sad",4,"standing, teary eyes, sad brows, frown, head slightly tilted"),
("skill1",8,"SKILL1"),
("skill2",8,"SKILL2"),
]

# Designs that only exist in this game: Gemini cannot look them up, so it gets the current sprite as a reference image.
ORIGINAL = {"catknight", "claude", "codex", "gemini", "opencode", "cursor", "aider"}
ONE_SHOT = {"kick", "surprised", "skill1", "skill2"}
STYLE = ("Cute chibi sticker sprite, 2-3 head tall proportions, thick dark-brown outline, flat cel shading with soft pink blush, "
 "simple clean shapes, kawaii desktop-pet game sprite look. Character faces RIGHT (side-3/4 view), full body incl. feet, centered in each cell "
 "with the same size and same foot baseline in every frame. Background: perfectly flat solid pure magenta #FF00FF "
 "(no gradient, no shadow, no text, no grid lines), so it can be chroma-keyed.")
ROW_RULES = ("evenly spaced with a wide empty magenta gap between frames. Draw NO divider lines, NO borders, NO frame boxes; each character "
 "stays fully inside its own cell and never touches or crosses a cell edge. Draw exactly {n} characters, not more, not fewer.")
EXTRA = (" IMPORTANT: draw each character SMALLER, occupying only about 60% of the width of its cell, with big empty magenta space on both sides, "
 "so nothing ever touches the cell edge. The whole background must be one perfectly uniform magenta with no faint lines, no seams and no darker stripes anywhere. "
 "Every frame must be a crisp, sharp, single clean drawing with solid flat colors: absolutely no motion blur, no ghost or afterimage, no speed lines, no smear.")
ARM = " The stretched arm must stay inside its own cell: draw the character on the LEFT part of the cell and keep the extended arm short enough to end before the cell's right edge."

HEAD = """TASK for Claude in Chrome (do it in the browser; I am already signed in to Gemini):

1. {open_chat}
2. {send}
3. Saving each image. DO NOT use Gemini's "Download full size" button: its upscaler returns blurry, ghosted or half-grey copies that differ from the picture on screen. Instead save the picture that is displayed, with this JavaScript run in the Gemini tab (javascript tool), once the answer has finished drawing (no stop button, image fully visible, not grey):
   const imgs=[...document.querySelectorAll('img')].filter(i=>i.naturalWidth>800); const im=imgs[imgs.length-1]; const c=document.createElement('canvas'); c.width=im.naturalWidth; c.height=im.naturalHeight; c.getContext('2d').drawImage(im,0,0); const blob=await new Promise(r=>c.toBlob(r,'image/png')); const a=document.createElement('a'); a.href=URL.createObjectURL(blob); a.download='NAME'; document.body.appendChild(a); a.click(); a.remove();
   Replace NAME with the file name given in the === line ({pattern}). It is saved to Chrome's download folder; the target folder is {raw}. If the file lands elsewhere, tell me the exact file names and the order so I can move them. Never add suffixes like _v2 or (1); if a file with that name exists, replace it.
4. Before saving each row image, check it: exactly the requested number of characters, no divider lines, no character touching a cell edge. If it fails, ask Gemini to redo that row (up to 2 retries) and download only the good one. If it still fails, download the best one and tell me which row.
5. Gemini may stop after about 10 images per turn. If so, reply "Ready, continue with the next rows" and carry on.
6. {others}
7. When finished, list the downloaded file names and stop.

PROMPTS (send the text only, not the === line):

"""

REAL_PEOPLE = {"trump", "putin", "xi", "kim"}

def write_reference(repo, cid, out):
    """Cuts the standing idle frame out of the current sheet, enlarged on white, as Gemini's reference image."""
    try:
        from PIL import Image
    except ImportError:
        sys.exit(f"{cid} is an original character and needs a reference image: run this with the venv python (pip install -r scripts/sprites/requirements.txt)")
    current = os.path.join(repo, "Sources", "OllieBoard", "Resources", "Sprites", f"{cid}.png")
    if not os.path.exists(current):
        sys.exit(f"{cid} is an original design with no sheet yet: pass --reference <picture of the character>")
    sheet = Image.open(current).convert("RGBA")
    frame = sheet.crop((0, 0, 256, 256))
    ref = Image.new("RGBA", (256, 256), (255, 255, 255, 255)); ref.alpha_composite(frame)
    path = os.path.join(out, f"{cid}_reference.png")
    ref.convert("RGB").resize((768, 768), Image.LANCZOS).save(path)
    return path

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("id", nargs="?"); ap.add_argument("--rows"); ap.add_argument("--list", action="store_true")
    ap.add_argument("--reference", help="picture of the character to attach to the model-sheet prompt (needed for a new original design)")
    o = ap.parse_args()
    if o.list or not o.id:
        sys.exit("known ids: " + ", ".join(CHARACTERS))
    if o.id not in CHARACTERS: sys.exit(f"unknown id {o.id!r}; add it to CHARACTERS. Known: {', '.join(CHARACTERS)}")
    name, look, s1, s2 = CHARACTERS[o.id]
    repo = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    out = os.path.join(repo, "build", "sprites", o.id); raw = os.path.join(out, "raw")
    os.makedirs(raw, exist_ok=True)
    wanted = None if not o.rows else {int(x) for x in o.rows.split(",")}
    rows = [(i, *r) for i, r in enumerate(ROWS) if s1 or not r[0].startswith("skill")]
    if wanted: rows = [r for r in rows if r[0] in wanted]
    redo = bool(wanted)
    body = ""
    ref = None
    if not redo and (o.reference or o.id in ORIGINAL):
        ref = os.path.abspath(o.reference) if o.reference else write_reference(repo, o.id, out)
        if not os.path.exists(ref): sys.exit(f"reference picture not found: {ref}")
        body += (f"=== STEP 0 - attach {ref} - save as {o.id}_step0_model_sheet.png ===\nThe attached image shows {name}"
                 f" (use this picture as the reference; do not search online for it). Redraw exactly this character as a chibi character model sheet, keeping its "
                 f"design, colors and accessories (key traits: {look}). {STYLE} Show 3 poses (front, side facing right, back) on one image. "
                 f"Keep this exact design for all following requests.\n\n")
    elif not redo:
        body += (f"=== STEP 0 - save as {o.id}_step0_model_sheet.png ===\nFirst look up official reference images of {name} online, then design a chibi "
                 f"character model sheet of this character (key traits: {look}). {STYLE} Show 3 poses (front, side facing right, back) on one image. "
                 f"Keep this exact design for all following requests.\n\n")
    for i, anim, n, desc in rows:
        desc = {"SKILL1": s1, "SKILL2": s2}.get(desc, desc)
        loop = "Frames play once, in order, as a one-shot action (not a loop)." if anim in ONE_SHOT else "Each frame is the next step of a smooth loop."
        extra = EXTRA + (ARM if (o.id, anim) == ("luffy", "skill1") else "")
        body += (f"=== ROW {i} - save as {o.id}_row{i}_{anim}.png ===\nUsing the same character design as the model sheet, draw a sprite animation strip: "
                 f"{n} frames side by side in ONE horizontal row, {n} equal square cells, {ROW_RULES.format(n=n)} Animation '{anim}': {desc}. {loop} {STYLE} "
                 f"Output aspect ratio {n}:1. Output at the highest resolution (2K).{extra}\n\n")
    first = "Open a NEW Gemini chat (gemini.google.com) and keep using that same chat for the whole task." if not redo else \
            "Open the existing Gemini chat where this character's model sheet was already made. If you cannot find it, tell me and stop."
    if ref:
        first += f" For STEP 0, first attach the image file {ref} to the message (Gemini's upload / + button), then send the prompt."
    if o.id in REAL_PEOPLE:
        first += " This is a playful caricature of a real politician; if Gemini refuses to draw it, stop and tell me (do not try to get around the refusal)."
    order = ", ".join(([] if redo else ["STEP 0"]) + [f"ROW {r[0]}" for r in rows])
    head = HEAD.format(open_chat=first, send=f"Send the prompts below ONE AT A TIME, in this order: {order}. Wait until each image is finished before sending the next one.",
                       raw=raw, pattern=f"{o.id}_rowN_name.png (the model sheet: {o.id}_step0_model_sheet.png)",
                       others="Do not redo any other row." if redo else "Do not skip any prompt.")
    path = os.path.join(out, "chrome-task.md")
    open(path, "w").write(head + body)
    print(f"Wrote {path}\nDownloads go to {raw}\nPaste the content of chrome-task.md into Claude in Chrome.")

if __name__ == "__main__":
    main()
