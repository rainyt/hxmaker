"""比较固定画面的新旧截图；移动场景的最终模拟帧数可能不同，不作逐像素断言。"""

import json
import sys
from pathlib import Path
from PIL import Image, ImageChops


def compare(first, second):
    left = Image.open(first).convert("RGB")
    right = Image.open(second).convert("RGB")
    if left.size != right.size:
        raise AssertionError(f"截图尺寸不同：{first} / {second}")
    difference = ImageChops.difference(left, right)
    return {
        "first": str(first), "second": str(second), "size": left.size,
        "differentPixels": sum(max(pixel) > 0 for pixel in difference.getdata()),
        "maxChannelDifference": max(upper for lower, upper in difference.getextrema()),
        "bounds": difference.getbbox(),
    }


results = []
for directory in map(Path, sys.argv[1:]):
    for first in sorted(directory.glob("*-graphics-*.png")):
        if "-moving" in first.name or first.name.endswith("-diff.png"):
            continue
        second = first.with_name(first.name.replace("-graphics-", "-direct-"))
        if second.exists():
            result = compare(first, second)
            results.append(result)
            print(f"{first.name}：差异像素 {result['differentPixels']}")
            if result["differentPixels"]:
                raise AssertionError(f"新旧画面不同：{first}")

output = Path("results/image-verification.json")
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(results, ensure_ascii=False, indent=2))
print(f"{len(results)} 组固定画面对照通过，详见 {output}")
