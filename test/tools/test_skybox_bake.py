"""天空资源工具回归：方向、跨面滤波、边框和旧格式兼容。"""
import importlib.util
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from PIL import Image

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('bake_ibl', ROOT / 'tools/bake-ibl.py')
bake = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bake)


class SkyboxBakeChecks(unittest.TestCase):
    def test_panorama_and_cube_directions(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            colors = {'px': (255, 0, 0), 'nx': (0, 255, 0), 'py': (0, 0, 255),
                      'ny': (255, 255, 0), 'pz': (255, 0, 255), 'nz': (0, 255, 255)}
            directions = {'px': (1, 0, 0), 'nx': (-1, 0, 0), 'py': (0, 1, 0),
                          'ny': (0, -1, 0), 'pz': (0, 0, 1), 'nz': (0, 0, -1)}
            for name, color in colors.items():
                Image.new('RGB', (8, 8), color).save(directory / (name + '.png'))
            source = bake.load_cube(directory, 2)
            for name, direction in directions.items():
                self.assertEqual(source(direction), tuple(c / 255 * 2 for c in colors[name]))
            # 检查相邻面的同一条边，过滤结果应连续。
            a, b = source((1, 0, 1 - 1e-6)), source((1 - 1e-6, 0, 1))
            self.assertLess(max(abs(x - y) for x, y in zip(a, b)), 0.001)
            bake.write_sky(directory, 32, source)
            with Image.open(directory / 'sky.png') as image:
                for y in range(image.height):
                    self.assertEqual(image.getpixel((0, y)), image.getpixel((32, y)))
                    self.assertEqual(image.getpixel((33, y)), image.getpixel((1, y)))
                for x in range(image.width):
                    self.assertEqual(image.getpixel((x, 0)), image.getpixel((x, 1)))
                    self.assertEqual(image.getpixel((x, 17)), image.getpixel((x, 16)))
            metadata = json.loads((directory / 'sky.json').read_text())
            self.assertEqual(metadata['format'], 'hxmaker-sky-1')
            self.assertEqual(metadata['radianceRange'], 2)
            # 同一图像载入全景后也应保持周向连续。
            Image.new('RGB', (30, 15), (128, 64, 255)).save(directory / 'panorama.png')
            panorama = bake.load_source(directory / 'panorama.png', 1)
            self.assertEqual(panorama((-1, 0, 1e-8)), panorama((-1, 0, -1e-8)))

    def test_cube_validation(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            with self.assertRaises(ValueError):
                bake.load_cube(directory, 1)
            for face in ('px', 'nx', 'py', 'ny', 'pz', 'nz'):
                Image.new('RGB', (8, 8)).save(directory / (face + '.png'))
            Image.new('RGB', (4, 4)).save(directory / 'nz.png')
            with self.assertRaises(ValueError):
                bake.load_cube(directory, 1)

    def test_hdr_source(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            path = directory / 'source.hdr'
            path.write_bytes(b'#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n\n-Y 1 +X 2\n' + bytes([128, 64, 32, 130]) * 2)
            source = bake.load_source(path, 1)
            self.assertEqual(source((1, 0, 0)), (2, 1, 0.5))
            bake.write_sky(directory, 16, source)
            metadata = json.loads((directory / 'sky.json').read_text())
            self.assertEqual(metadata['radianceRange'], 2)
            with Image.open(directory / 'sky.png') as image:
                self.assertEqual(image.getpixel((1, 1)), (255, 128, 64))

    def test_cli_legacy_and_sky_only(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            base = [sys.executable, str(ROOT / 'tools/bake-ibl.py'), '--output', str(output)]
            subprocess.run(base + ['--width', '16', '--samples', '16', '--levels', '2'], check=True, capture_output=True)
            metadata = json.loads((output / 'environment.json').read_text())
            self.assertEqual(metadata['format'], 'hxmaker-ibl-1')
            self.assertFalse((output / 'sky.png').exists())
            before = (output / 'environment.png').read_bytes()
            subprocess.run(base + ['--sky-only', '--sky-width', '30'], check=True, capture_output=True)
            self.assertEqual(before, (output / 'environment.png').read_bytes())
            with Image.open(output / 'sky.png') as image:
                self.assertEqual(image.size, (32, 17))
            invalid = subprocess.run(base + ['--sky-only'], capture_output=True)
            self.assertNotEqual(invalid.returncode, 0)


if __name__ == '__main__':
    unittest.main()
