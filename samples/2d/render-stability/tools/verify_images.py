from pathlib import Path
import json
from PIL import Image, ImageChops

# 全屏比对用于发现黑块、错图、滤镜缺失和裁剪状态污染。
root = Path(__file__).resolve().parent.parent / "results"
base = Image.open(root / "initial.png").convert("RGB")
checks = []
report = json.loads((root / "report.json").read_text())
if (root / "fault-budget.json").exists():
    faults = json.loads((root / "fault-budget.json").read_text())
    if faults.get("passed") and faults["before"]["buildId"] == report["checkpoints"][0]["state"]["buildId"]:
        difference = ImageChops.difference(base, Image.open(root / "astc-fallback.png").convert("RGB"))
        count = sum(value != (0, 0, 0) for value in difference.getdata())
        checks.append({"file": "astc-fallback.png", "differentPixels": count, "passed": count == 0})
for name in ["after-foreground.png", "after-resize.png", "masks-on.png", "textures-0.png", "after-200-cycles.png", "after-idle-clean.png", "restored-1.png", "restored-20.png", "after-fault.png", "after-all-faults.png"]:
    image = Image.open(root / name).convert("RGB")
    difference = ImageChops.difference(base, image)
    pixels = sum(value != (0, 0, 0) for value in difference.getdata())
    checks.append({"file": name, "differentPixels": pixels, "passed": pixels == 0})

def pixel(filename, x, y, color):
    value = Image.open(root / filename).convert("RGB").getpixel((x, y))
    checks.append({"file": filename, "position": [x, y], "actual": value, "expected": color,
                   "passed": max(abs(a - b) for a, b in zip(value, color)) <= 1})

for count in [1, 8, 16]:
    for x in [48, 96, 144]:
        pixel(f"compiled-{count}.png", x, 448, (85, 85, 85))
pixel("initial.png", 440, 128, (85, 85, 85))
pixel("initial.png", 560, 128, (85, 85, 85))
pixel("initial.png", 620, 128, (255, 255, 255))
pixel("initial.png", 310, 280, (0, 255, 255))
pixel("initial.png", 360, 280, (22, 33, 52))
pixel("initial.png", 440, 280, (22, 33, 52))
pixel("initial.png", 480, 280, (255, 0, 255))
pixel("masks-off.png", 360, 280, (0, 255, 255))
pixel("masks-off.png", 440, 280, (255, 0, 255))
pixel("fault-isolated.png", 830, 128, (0, 255, 0))
if report["checkpoints"][0]["state"]["astc"]["enabled"]:
    pixel("initial.png", 700, 280, (255, 128, 0))
(root / "pixel-checks.json").write_text(json.dumps(checks, ensure_ascii=False, indent=2))
for check in checks:
    if not check["passed"]:
        print(check)
assert all(check["passed"] for check in checks), "发现像素对照差异"
print(f"像素对照通过：{len(checks)}项")
