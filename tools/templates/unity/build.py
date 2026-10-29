#!/usr/bin/env python3
"""编译本项目的 Haxe 代码并导入 Unity。"""
from pathlib import Path
import subprocess
import sys

project: Path = Path(__file__).resolve().parent
builder: str = ::unity_builder_json::
subprocess.run([sys.executable, builder, '--project', str(project), *sys.argv[1:]], check=True)
