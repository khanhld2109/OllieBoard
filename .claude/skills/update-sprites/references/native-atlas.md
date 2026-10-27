# Native transparent atlas route

Use this when the user selects the host's built-in image generator instead of Gemini. In Codex, use the available imagegen skill/tool. In Claude Code, discover an actual image-generation tool; if none exists, report that limitation and hand off the prompts. Do not pretend the language model or browser can generate an image without a supported tool.

## Generate and pack

- Read the shared sprite contract in the parent skill. Register the character in `scripts/sprites/gen_prompts.py`'s `CHARACTERS` table for id validation and animation descriptions; this does not invoke Gemini.
- Generate four RGBA atlases, each exactly 8 columns × 4 rows. Use a 2:1 landscape canvas with native transparency, clear gaps between cells, no labels, grid, shadows, or floating effects. Keep every character fully inside the canvas. Use the first atlas as the identity/style reference for the other three.
- Atlas A: idle, walk, run, kick. B: carry, happy, bored, yawn. C: sleep, grumpy, dragged, surprised. D: work, sad, skill1, skill2.
- Put animation frames in the leftmost cells in playback order. When an animation uses fewer than 8 frames, extra right-hand cells are unused. All eight skill cells are used and must match the runtime action timing. Ask for actual distinct action poses, not a repeated sticker.
- Keep head/body size and camera consistent. Sitting and sliding silhouettes should be shorter than standing. Carry and dragged need both arms overhead. The app supplies effects and carried icons.
- Save outputs inside the workspace and inspect all four atlases. Never run transparent atlases through `assemble.py`: its Gemini chroma key, watermark mask and skin correction would damage them.

```sh
.venv/bin/python scripts/sprites/assemble_atlas.py <id> <atlas-a.png> <atlas-b.png> <atlas-c.png> <atlas-d.png>
```

The packer separates connected drawings by their alpha, assigns them to the 8×4 grid, and uses one consistent scale across all atlases. It preserves native colours, transparency and frame order, writing `build/sprites/<id>/<id>.png` plus a preview and row report. It rejects opaque backgrounds, missing cells, touching drawings and clipped outer edges. All 32 slots in each input atlas must contain a character, including unused trailing poses. These checks cannot prove the right pose or action timing; inspect the output and animated playback before installation. Regenerate failed art with the image tool.

Once it passes, rerun with `--install`. The command installs the PNG and lists it in `custom-sheets.txt`. Follow the parent skill's shared build and process-local testing guidance; substitute this packer for its Gemini `assemble.py` install command. Keep the final prompts and raw atlases under `build/sprites/<id>/` for local reproduction. Report image generation, structural checks, visual review and live app checks separately.
