#!/usr/bin/env python3
"""生成自有 PBR 贴图球体与内嵌 GLB 示例资源，不运行引擎或测试。"""

import json
import math
from pathlib import Path
import struct
import zlib


def png(width, height, pixels):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    rows = b''.join(b'\x00' + bytes(pixels[y * width * 3:(y + 1) * width * 3]) for y in range(height))
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(rows, 9)) + chunk(b'IEND', b''))


def main():
    output = Path(__file__).resolve().parents[1] / 'samples/3d/pbr-material/Assets/pbr'
    output.mkdir(parents=True, exist_ok=True)
    width, height = 128, 64
    maps = {name: bytearray() for name in ['base-color', 'metallic-roughness', 'normal', 'occlusion', 'emissive']}
    for y in range(height):
        for x in range(width):
            u, v = (x + 0.5) / width, (y + 0.5) / height
            checker = (int(u * 8) + int(v * 4)) % 2
            maps['base-color'].extend((220, 148, 66) if checker else (66, 148, 205))
            maps['metallic-roughness'].extend((255, round((0.12 + 0.78 * u) * 255), 255 if v < 0.5 else 0))
            nx, ny = 0.45 * math.sin(u * math.pi * 16), 0.45 * math.sin(v * math.pi * 8)
            nz = math.sqrt(1 - nx * nx - ny * ny)
            maps['normal'].extend(round((c * 0.5 + 0.5) * 255) for c in (nx, ny, nz))
            occlusion = round((0.35 + 0.65 * abs(math.sin(u * math.pi * 8) * math.sin(v * math.pi * 4))) * 255)
            maps['occlusion'].extend((occlusion, occlusion, occlusion))
            glowing = abs(math.sin(v * math.pi * 6)) < 0.18 and abs(math.sin(u * math.pi * 8)) < 0.35
            maps['emissive'].extend((255, 120, 20) if glowing else (0, 0, 0))
    document = {'asset': {'version': '2.0', 'generator': 'hxmaker 自有 PBR 示例资源生成器'},
                'bufferViews': [], 'accessors': [], 'images': [], 'textures': [],
                'samplers': [{'wrapS': 10497, 'wrapT': 33648, 'magFilter': 9729, 'minFilter': 9729}],
                'scene': 0, 'scenes': [{'nodes': [0]}],
                'nodes': [{'name': 'PBR 贴图球', 'mesh': 0, 'translation': [0, 1.25, 0.7]}]}
    binary = bytearray()

    def view(data, target=None):
        binary.extend(b'\x00' * (-len(binary) % 4))
        record = {'buffer': 0, 'byteOffset': len(binary), 'byteLength': len(data)}
        if target is not None:
            record['target'] = target
        document['bufferViews'].append(record)
        binary.extend(data)
        return len(document['bufferViews']) - 1

    def accessor(values, components, kind, component_type=5126):
        code = 'f' if component_type == 5126 else 'H'
        record = {'bufferView': view(struct.pack('<' + code * len(values), *values), 34963 if kind == 'SCALAR' else 34962),
                  'componentType': component_type, 'count': len(values) // components, 'type': kind}
        if kind == 'VEC3':
            record['min'] = [min(values[i::components]) for i in range(components)]
            record['max'] = [max(values[i::components]) for i in range(components)]
        document['accessors'].append(record)
        return len(document['accessors']) - 1

    positions, normals, tangents, uvs, indices = [], [], [], [], []
    segments, rings = 48, 24
    for ring in range(rings + 1):
        for segment in range(segments + 1):
            theta, phi = ring * math.pi / rings, segment * math.pi * 2 / segments
            n = (math.sin(theta) * math.cos(phi), math.cos(theta), math.sin(theta) * math.sin(phi))
            positions.extend(c * 1.2 for c in n)
            normals.extend(n)
            tangents.extend((-math.sin(phi), 0, math.cos(phi), 1))
            uvs.extend((segment / segments, ring / rings))
    for ring in range(rings):
        for segment in range(segments):
            a, b = ring * (segments + 1) + segment, (ring + 1) * (segments + 1) + segment
            if ring:
                indices.extend((a, a + 1, b))
            if ring < rings - 1:
                indices.extend((a + 1, b + 1, b))
    attributes = {'POSITION': accessor(positions, 3, 'VEC3'), 'NORMAL': accessor(normals, 3, 'VEC3'),
                  'TANGENT': accessor(tangents, 4, 'VEC4'), 'TEXCOORD_0': accessor(uvs, 2, 'VEC2')}
    index_accessor = accessor(indices, 1, 'SCALAR', 5123)
    for name, pixels in maps.items():
        image = png(width, height, pixels)
        (output / (name + '.png')).write_bytes(image)
        document['images'].append({'name': name, 'mimeType': 'image/png', 'bufferView': view(image)})
        document['textures'].append({'source': len(document['images']) - 1, 'sampler': 0})
    document['materials'] = [{'name': '完整 PBR 贴图示例',
                              'pbrMetallicRoughness': {'baseColorFactor': [1, 1, 1, 1], 'baseColorTexture': {'index': 0},
                                                       'metallicFactor': 1, 'roughnessFactor': 1, 'metallicRoughnessTexture': {'index': 1}},
                              'normalTexture': {'index': 2, 'scale': 1},
                              'occlusionTexture': {'index': 3, 'strength': 1},
                              'emissiveTexture': {'index': 4}, 'emissiveFactor': [1, 1, 1]}]
    document['meshes'] = [{'primitives': [{'attributes': attributes, 'indices': index_accessor, 'material': 0, 'mode': 4}]}]
    document['buffers'] = [{'byteLength': len(binary)}]
    raw_json = json.dumps(document, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
    raw_json += b' ' * (-len(raw_json) % 4)
    binary.extend(b'\x00' * (-len(binary) % 4))
    glb = (struct.pack('<III', 0x46546c67, 2, 12 + 8 + len(raw_json) + 8 + len(binary))
           + struct.pack('<II', len(raw_json), 0x4e4f534a) + raw_json + struct.pack('<II', len(binary), 0x004e4942) + binary)
    (output / 'material-sphere.glb').write_bytes(glb)
    print('已生成 PBR 贴图及内嵌 GLB 示例：' + str(output))


if __name__ == '__main__':
    main()
