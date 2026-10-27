"""Regression checks using synthetic strips in an isolated repository."""
import contextlib
import io
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import numpy as np
from PIL import Image, ImageDraw

import assemble
import gen_prompts


def strip(count, variant=0):
    image = Image.new("RGB", (count * 128, 128), (255, 0, 255))
    draw = ImageDraw.Draw(image)
    rng = np.random.default_rng(variant)
    for frame in range(count):
        x = frame * 128
        # Keep a connected, solid silhouette with pose variation between rows.
        left = int(rng.integers(22, 42))
        right = int(rng.integers(84, 104))
        top = int(rng.integers(14, 35))
        colour = (20 + variant * 7 % 70, 120 + variant * 9 % 100, 200)
        draw.rectangle((x + left, top, x + right, 108), fill=colour)
        draw.ellipse((x + 43, 4, x + 81, 40), fill=colour)
    return image


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ollieboard-sprite-test-")
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.scripts = self.repo / "scripts" / "sprites"
        self.scripts.mkdir(parents=True)
        self.sprites = self.repo / "Sources" / "OllieBoard" / "Resources" / "Sprites"
        self.sprites.mkdir(parents=True)
        generator = self.repo / "Sources" / "SpriteGen" / "main.swift"
        generator.parent.mkdir(parents=True)
        generator.write_text("// respects custom-sheets.txt\n")
        self.raw = self.repo / "build" / "sprites" / "luffy" / "raw"
        self.raw.mkdir(parents=True)
        self.target = self.sprites / "luffy.png"
        self.target.write_bytes(b"existing-sheet")

    def assemble(self, *args):
        output = io.StringIO()
        with patch.object(assemble, "__file__", str(self.scripts / "assemble.py")), \
             patch.object(sys, "argv", ["assemble.py", *args]), \
             contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
            try:
                assemble.main()
            except SystemExit as error:
                return error.code, output.getvalue()
        return 0, output.getvalue()

    def rows(self):
        for row, (name, count) in enumerate(assemble.ROWS):
            strip(count, row).save(self.raw / f"luffy_row{row}_{name}.png")

    def test_keep_bad_cannot_install(self):
        code, _ = self.assemble("luffy", "--keep-bad", "--install")
        self.assertEqual(code, 2)
        self.assertEqual(self.target.read_bytes(), b"existing-sheet")

    def test_invalid_arguments_cannot_write(self):
        for args in [("../escape",), ("unknown",), ("luffy", "--skin", "1.1"),
                     ("luffy", "--skin", "nan")]:
            with self.subTest(args=args):
                code, _ = self.assemble(*args)
                self.assertEqual(code, 2)
        self.assertFalse((self.repo / "build" / "escape").exists())

    def test_missing_rows_leave_installed_sheet_untouched(self):
        strip(4).save(self.raw / "luffy_row0_idle.png")
        code, output = self.assemble("luffy", "--skin", "0", "--install")
        self.assertNotEqual(code, 0)
        self.assertIn("MISSING", output)
        self.assertEqual(self.target.read_bytes(), b"existing-sheet")

    def test_other_character_and_wrong_row_name_are_ignored(self):
        strip(4).save(self.raw / "zoro_row0_idle.png")
        strip(4).save(self.raw / "luffy_row0_sleep.png")
        code, _ = self.assemble("luffy", "--install")
        self.assertNotEqual(code, 0)
        self.assertEqual(self.target.read_bytes(), b"existing-sheet")

    def test_skill_frame_count_must_be_exact(self):
        self.rows()
        strip(9, 14).save(self.raw / "luffy_row14_skill1.png")
        code, output = self.assemble("luffy", "--skin", "0", "--install")
        self.assertNotEqual(code, 0)
        self.assertIn("skill timing requires exactly 8", output)
        self.assertEqual(self.target.read_bytes(), b"existing-sheet")

    def test_damaged_skill_frame_is_not_replaced_at_install(self):
        self.rows()
        image = strip(8, 14)
        draw = ImageDraw.Draw(image)
        draw.rectangle((0, 0, 127, 127), fill=(255, 0, 255))
        draw.rectangle((50, 10, 78, 108), fill=(30, 160, 200))
        image.save(self.raw / "luffy_row14_skill1.png")
        code, output = self.assemble("luffy", "--skin", "0", "--install")
        self.assertNotEqual(code, 0)
        self.assertIn("unusable frames", output)
        self.assertEqual(self.target.read_bytes(), b"existing-sheet")

    def test_duplicate_rows_block_installation(self):
        self.rows()
        shutil.copyfile(self.raw / "luffy_row0_idle.png", self.raw / "luffy_row6_bored.png")
        code, output = self.assemble("luffy", "--skin", "0", "--install")
        self.assertNotEqual(code, 0)
        self.assertIn("same picture as row 0", output)
        self.assertEqual(self.target.read_bytes(), b"existing-sheet")

    def test_valid_sheet_installs_and_preserves_other_ids(self):
        self.rows()
        listing = self.sprites / "custom-sheets.txt"
        listing.write_text("# manually drawn\nzoro")
        code, output = self.assemble("luffy", "--skin", "0", "--install")
        self.assertEqual(code, 0, output)
        with Image.open(self.target) as sheet:
            self.assertEqual(sheet.size, (2048, 4096))
            self.assertEqual(sheet.mode, "RGBA")
            for row, (_, count) in enumerate(assemble.ROWS):
                for frame in range(count):
                    cell = sheet.crop((frame * 256, row * 256, (frame + 1) * 256, (row + 1) * 256))
                    self.assertIsNotNone(cell.getbbox())
        self.assertEqual(listing.read_text(), "# manually drawn\nzoro\nluffy\n")
        code, output = self.assemble("luffy", "--skin", "0", "--install")
        self.assertEqual(code, 0, output)
        self.assertEqual(listing.read_text().splitlines().count("luffy"), 1)

    def test_missing_spritegen_guard_blocks_installation(self):
        self.rows()
        (self.repo / "Sources" / "SpriteGen" / "main.swift").write_text("// old generator\n")
        code, _ = self.assemble("luffy", "--skin", "0", "--install")
        self.assertNotEqual(code, 0)
        self.assertEqual(self.target.read_bytes(), b"existing-sheet")

    def prompt(self, *args):
        script = self.scripts / "gen_prompts.py"
        shutil.copyfile(gen_prompts.__file__, script)
        return subprocess.run([sys.executable, str(script), *args], capture_output=True, text=True)

    def test_prompt_cli_lists_and_validates_rows(self):
        result = self.prompt("--list")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("luffy", result.stdout)
        for rows in ("", "abc", "-1", "16"):
            result = self.prompt("luffy", "--rows", rows)
            self.assertEqual(result.returncode, 2, result.stderr)
        result = self.prompt("codex", "--rows", "14")
        self.assertEqual(result.returncode, 2)

    def test_retry_only_emits_requested_rows(self):
        result = self.prompt("luffy", "--rows", "2,14")
        self.assertEqual(result.returncode, 0, result.stderr)
        task = (self.raw.parent / "gemini-task.md").read_text()
        self.assertIn("=== ROW 2 ", task)
        self.assertIn("=== ROW 14 ", task)
        self.assertNotIn("=== ROW 0 ", task)
        self.assertNotIn("=== STEP 0 ", task)

    def test_full_prompt_contains_model_and_all_rows(self):
        result = self.prompt("luffy")
        self.assertEqual(result.returncode, 0, result.stderr)
        task = (self.raw.parent / "gemini-task.md").read_text()
        self.assertIn("=== STEP 0 ", task)
        self.assertEqual(task.count("=== ROW "), 16)


if __name__ == "__main__":
    unittest.main()
