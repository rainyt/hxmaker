#!/usr/bin/env python3
"""准备验收资产：复制低模机器人、生成高密度全双权重版本和纹理压力素材。"""
import hashlib
import json
import shutil
import struct
import subprocess
import sys
import zlib
from pathlib import Path

root = Path(__file__).resolve().parents[1]
assets = root/'Assets'
assets.mkdir(exist_ok=True)
source = root.parent/'textured-character'
shutil.copy2(source/'Assets/robot.glb', assets/'robot.glb')
subprocess.run([sys.executable, str(source/'SourceAssets/generate_assets.py'), '--output-root',str(root),
                '--name','robot-dense','--subdivisions','8','--all-blended','--no-source-images'],check=True)


def png(index):
    def chunk(tag, value):
        return struct.pack('>I',len(value))+tag+value+struct.pack('>I',zlib.crc32(tag+value)&0xffffffff)
    color = ((index*47+50)%190+40,(index*83+30)%190+40,(index*29+80)%190+40)
    pixels = bytearray()
    for y in range(64):
        pixels.append(0)
        for x in range(64):
            edge = min(x,y,63-x,63-y)<3
            bright = ((x//8+y//8+index)%2)==0
            pixels.extend((*((255,255,255) if edge else tuple(min(255,c+(25 if bright else 0)) for c in color)),255))
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',64,64,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(pixels,9))+chunk(b'IEND',b'')


for i in range(20):
    (assets/('tile_%02d.png'%i)).write_bytes(png(i))
manifest = {'schemaVersion':1,'description':'原创固定负载；高密度版本增加计算量，不代表美术复杂度',
            'models':{'robot':{'triangles':192,'vertices':384,'joints':15,'meshes':16,'blendedMeshes':1},
                      'robot-dense':{'triangles':12288,'vertices':7776,'joints':15,'meshes':16,'blendedMeshes':16}},
            'files':[]}
for p in sorted(assets.iterdir()):
    if p.suffix not in ('.png','.glb'):
        continue
    data = p.read_bytes()
    manifest['files'].append({'name':p.name,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
(assets/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('已准备验收资产和 SHA-256 清单。')
