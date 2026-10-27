"""Checks for the native-alpha sprite packer; uses no generated/user artwork."""
import contextlib
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image, ImageDraw

import assemble_atlas


class AtlasTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ollieboard-atlas-test-")
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.path = self.repo / "atlas.png"

    def fixture(self):
        image = Image.new("RGBA", (800, 400))
        draw = ImageDraw.Draw(image)
        for row in range(4):
            for column in range(8):
                # Alternate vertical offsets: there is no single horizontal
                # line that separates all columns, but characters do not touch.
                y = row * 100 + (5 if column % 2 else 25)
                draw.rectangle((column * 100 + 20, y, column * 100 + 79, y + 70),
                               fill=(30 + column * 20, 40 + row * 40, 180, 180))
        image.save(self.path)
        return image

    def test_offset_grid_preserves_colours_and_alpha(self):
        self.fixture()
        rows, pitch = assemble_atlas.unpack(self.path)
        self.assertEqual(pitch, 100)
        self.assertEqual(len(rows), 4)
        for row, cells in enumerate(rows):
            self.assertEqual(len(cells), 8)
            for column, cell in enumerate(cells):
                box = cell.getbbox()
                pixel = cell.getpixel(((box[0] + box[2]) // 2, (box[1] + box[3]) // 2))
                self.assertEqual(pixel, (30 + column * 20, 40 + row * 40, 180, 180))

    def test_missing_character_is_rejected(self):
        image = self.fixture()
        ImageDraw.Draw(image).rectangle((0, 0, 99, 99), fill=(0, 0, 0, 0))
        image.save(self.path)
        with self.assertRaisesRegex(ValueError, "missing/incomplete"):
            assemble_atlas.unpack(self.path)

    def test_connected_neighbours_are_rejected(self):
        image = self.fixture()
        ImageDraw.Draw(image).rectangle((50, 35, 150, 65), fill=(50, 50, 50, 255))
        image.save(self.path)
        with self.assertRaises(ValueError):
            assemble_atlas.unpack(self.path)

    def test_opaque_background_is_rejected(self):
        Image.new("RGBA", (800, 400), "white").save(self.path)
        with self.assertRaisesRegex(ValueError, "transparent"):
            assemble_atlas.unpack(self.path)

    def test_clipped_outer_edge_is_rejected(self):
        image = self.fixture()
        ImageDraw.Draw(image).rectangle((20, 0, 79, 30), fill=(50, 50, 50, 255))
        image.save(self.path)
        with self.assertRaisesRegex(ValueError, "outer canvas edge"):
            assemble_atlas.unpack(self.path)

    def test_install_has_expected_frame_layout(self):
        self.fixture()
        scripts = self.repo / "scripts" / "sprites"
        scripts.mkdir(parents=True)
        sprites = self.repo / "Sources" / "OllieBoard" / "Resources" / "Sprites"
        sprites.mkdir(parents=True)
        generator = self.repo / "Sources" / "SpriteGen" / "main.swift"
        generator.parent.mkdir(parents=True)
        generator.write_text("// custom-sheets.txt")
        with patch.object(assemble_atlas, "__file__", str(scripts / "assemble_atlas.py")), \
             patch.object(sys, "argv", ["assemble_atlas.py", "gugugaga", *([str(self.path)] * 4), "--install"]), \
             contextlib.redirect_stdout(io.StringIO()):
            assemble_atlas.main()
        sheet = Image.open(sprites / "gugugaga.png")
        self.assertEqual(sheet.size, (2048, 4096))
        total = 0
        for row, (_, count, _) in enumerate(assemble_atlas.ROWS):
            total += count
            for column in range(8):
                cell = sheet.crop((column * 256, row * 256, (column + 1) * 256, (row + 1) * 256))
                self.assertEqual(cell.getbbox() is not None, column < count)
        self.assertEqual(total, 89)
        self.assertEqual((sprites / "custom-sheets.txt").read_text(), "gugugaga\n")


if __name__ == "__main__":
    unittest.main()
