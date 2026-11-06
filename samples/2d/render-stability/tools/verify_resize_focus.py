from pathlib import Path
import json
from PIL import Image, ImageChops

# 检查实际像素，避免引擎标志恢复但画布仍空白的假通过。
root = Path(__file__).resolve().parent.parent / 'results' / 'resize-focus'
checks = []

def red(name, x, y, expected):
    color = Image.open(root / name).convert('RGB').getpixel((x, y))
    passed = (color == (255, 0, 0)) == expected
    checks.append({'file': name, 'position': [x, y], 'color': color,
                   'expectedRed': expected, 'passed': passed})

red('before-initial.png', 64, 128, True)
red('before-blurred-resize.png', 53, 107, False)
red('before-focus-restored.png', 53, 107, True)
red('after-blurred-resize.png', 53, 107, True)
base = Image.open(root / 'after-initial.png').convert('RGB')
for name in ['after-unfocused-restored-size.png', 'after-visible-without-focus.png']:
    image = Image.open(root / name).convert('RGB')
    difference = ImageChops.difference(base, image)
    count = sum(value != (0, 0, 0) for value in difference.getdata())
    checks.append({'file': name, 'differentPixels': count, 'passed': count == 0})
(root / 'pixels.json').write_text(json.dumps(checks, ensure_ascii=False, indent=2))
assert all(check['passed'] for check in checks), json.dumps(checks, ensure_ascii=False)
print(f'失焦缩放像素验收通过：{len(checks)}项')
