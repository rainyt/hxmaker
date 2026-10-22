#!/usr/bin/env python3
"""将等距柱状环境图离线预积分为 hxmaker IBL 图集；不依赖 GPU 或运行中的引擎。"""

import argparse
import json
import math
from pathlib import Path
import struct
import zlib


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def normalize(v):
    length = math.sqrt(dot(v, v))
    return tuple(x / max(length, 1e-12) for x in v)


def basis(n):
    tangent = normalize(cross((0, 1, 0) if abs(n[1]) < 0.99 else (1, 0, 0), n))
    return tangent, cross(n, tangent)


def to_world(local, n, tangent, bitangent):
    return tuple(tangent[i] * local[0] + bitangent[i] * local[1] + n[i] * local[2] for i in range(3))


def direction(u, v):
    theta, phi = v * math.pi, (u - 0.5) * 2 * math.pi
    return (math.sin(theta) * math.cos(phi), math.cos(theta), math.sin(theta) * math.sin(phi))


def sequence(count):
    result = []
    for i in range(count):
        value, inverse, bit = i, 0., 0.5
        while value:
            inverse += (value & 1) * bit
            value >>= 1
            bit *= 0.5
        result.append(((i + 0.5) / count, inverse))
    return result


def ggx_samples(roughness, points):
    alpha2 = max(roughness, 0.045) ** 4
    result = []
    for u, v in points:
        phi = 2 * math.pi * u
        cosine = math.sqrt((1 - v) / (1 + (alpha2 - 1) * v))
        sine = math.sqrt(max(0, 1 - cosine * cosine))
        result.append((math.cos(phi) * sine, math.sin(phi) * sine, cosine))
    return result


def studio(n):
    """程序生成的示例摄影棚，线性辐射值；没有第三方图片或授权依赖。"""
    sky = max(n[1], 0)
    base = [0.09 + 0.3 * sky, 0.12 + 0.4 * sky, 0.18 + 0.55 * sky]
    for center, color, power in [
        (normalize((1, 1, 1)), (5., 4.4, 3.5), 22),
        (normalize((-1, 0.5, -0.4)), (1.4, 2.2, 4.), 35),
    ]:
        weight = max(dot(center, n), 0) ** power
        base = [base[i] + color[i] * weight for i in range(3)]
    return tuple(base)


def read_hdr(path):
    """读取常见 -Y/+X 朝向的 Radiance RGBE，支持逐通道 RLE 和原始扫描行。"""
    with path.open('rb') as stream:
        if stream.readline().strip() not in (b'#?RADIANCE', b'#?RGBE'):
            raise ValueError('输入不是 Radiance RGBE 文件')
        header = []
        while True:
            line = stream.readline()
            if not line:
                raise ValueError('HDR 文件头不完整')
            if not line.strip():
                break
            header.append(line.strip())
        if b'FORMAT=32-bit_rle_rgbe' not in header:
            raise ValueError('仅支持 RGBE 格式，不支持 XYZE')
        resolution = stream.readline().split()
        if len(resolution) != 4 or resolution[0] != b'-Y' or resolution[2] != b'+X':
            raise ValueError('HDR 当前要求 -Y 高度 +X 宽度的扫描方向')
        height, width = int(resolution[1]), int(resolution[3])
        if width < 2 or height < 1 or width * height > 16777216:
            raise ValueError('HDR 尺寸无效或超过 1600 万像素')
        pixels = []
        for _ in range(height):
            first = stream.read(4)
            if len(first) != 4:
                raise ValueError('HDR 扫描行不完整')
            raw_row = True
            if 8 <= width <= 32767 and first[:2] == b'\x02\x02' and first[2] < 128:
                if (first[2] << 8 | first[3]) != width:
                    raise ValueError('HDR 扫描行宽度不一致')
                raw_row = False
                channels = []
                for _ in range(4):
                    channel = bytearray()
                    while len(channel) < width:
                        code = stream.read(1)
                        if not code or code[0] == 0:
                            raise ValueError('HDR RLE 数据无效')
                        length = code[0] - 128 if code[0] > 128 else code[0]
                        data = stream.read(1 if code[0] > 128 else length)
                        if len(data) != (1 if code[0] > 128 else length):
                            raise ValueError('HDR RLE 数据截断')
                        channel.extend(data * length if code[0] > 128 else data)
                        if len(channel) > width:
                            raise ValueError('HDR RLE 超过扫描行宽度')
                    channels.append(channel)
                row = zip(*channels)
            else:
                raw = first + stream.read(width * 4 - 4)
                if len(raw) != width * 4:
                    raise ValueError('HDR 像素数据截断')
                row = [raw[i:i + 4] for i in range(0, len(raw), 4)]
            for r, g, b, exponent in row:
                if raw_row and r == g == b == 1 and exponent:
                    raise ValueError('不支持旧式 RGBE 游程编码，请重新保存为现代 HDR')
                factor = math.ldexp(1., exponent - 136) if exponent else 0.
                pixels.append((r * factor, g * factor, b * factor))
    return width, height, pixels


def load_source(path, exposure):
    if path is None:
        return lambda n: tuple(c * exposure for c in studio(n))
    if path.suffix.lower() == '.hdr':
        width, height, pixels = read_hdr(path)
    else:
        try:
            from PIL import Image
        except ImportError as error:
            raise ValueError('读取 PNG/JPEG 需要 Pillow；HDR 和程序示例不需要额外依赖') from error
        with Image.open(path) as image:
            width, height = image.size
            if width < 2 or height < 1 or width * height > 16777216:
                raise ValueError('输入图片尺寸无效或超过 1600 万像素')
            pixels = [tuple(c / 255 / 12.92 if c / 255 <= 0.04045 else ((c / 255 + 0.055) / 1.055) ** 2.4
                            for c in pixel) for pixel in image.convert('RGB').getdata()]
    if width != height * 2:
        raise ValueError('输入必须为宽高比 2:1 的等距柱状全景图')

    def sample(n):
        u = math.atan2(n[2], n[0]) / (2 * math.pi) + 0.5
        v = math.acos(max(-1, min(1, n[1]))) / math.pi
        x, y = u * width - 0.5, max(0, min(height - 1, v * height - 0.5))
        x0, y0 = math.floor(x), math.floor(y)
        tx, ty = x - x0, y - y0
        corners = [pixels[y0 * width + x0 % width], pixels[y0 * width + (x0 + 1) % width],
                   pixels[min(y0 + 1, height - 1) * width + x0 % width],
                   pixels[min(y0 + 1, height - 1) * width + (x0 + 1) % width]]
        return tuple(((corners[0][i] * (1 - tx) + corners[1][i] * tx) * (1 - ty)
                      + (corners[2][i] * (1 - tx) + corners[3][i] * tx) * ty) * exposure for i in range(3))
    return sample


def load_cube(directory, exposure):
    """六面约定：px/nx/py/ny/pz/nz；每张图从左上角读取，采用 OpenGL 面方向。"""
    from array import array
    faces = {}
    size = None
    for name in ('px', 'nx', 'py', 'ny', 'pz', 'nz'):
        files = [directory / (name + suffix) for suffix in ('.png', '.jpg', '.jpeg', '.hdr')]
        files = [file for file in files if file.is_file()]
        if len(files) != 1:
            raise ValueError('每个立方体面必须且只能有一张图片：' + name)
        file = files[0]
        if file.suffix == '.hdr':
            width, height, pixels = read_hdr(file)
        else:
            try:
                from PIL import Image
            except ImportError as error:
                raise ValueError('读取 PNG/JPEG 六面图片需要 Pillow') from error
            with Image.open(file) as image:
                width, height = image.size
                if width <= 0 or width != height or width > 4096:
                    raise ValueError('六面图片必须为不超过 4096 的同尺寸正方形')
                pixels = [tuple(c / 255 / 12.92 if c / 255 <= 0.04045 else ((c / 255 + 0.055) / 1.055) ** 2.4
                                for c in pixel) for pixel in image.convert('RGB').getdata()]
        if width != height or width > 4096 or (size is not None and width != size):
            raise ValueError('六面图片必须为不超过 4096 的同尺寸正方形')
        size = width
        faces[name] = array('f', (channel for pixel in pixels for channel in pixel))
        del pixels

    def locate(n):
        x, y, z = n
        ax, ay, az = abs(x), abs(y), abs(z)
        if ax >= ay and ax >= az:
            return ('px', -z / ax, -y / ax) if x >= 0 else ('nx', z / ax, -y / ax)
        if ay >= az:
            return ('py', x / ay, z / ay) if y >= 0 else ('ny', x / ay, -z / ay)
        return ('pz', x / az, -y / az) if z >= 0 else ('nz', -x / az, -y / az)

    def texel(face, x, y):
        if not (0 <= x < size and 0 <= y < size):
            # 滤波越过面边界时转到邻面，避免转换后的全景出现夹边细线。
            u, v = (x + 0.5) / size * 2 - 1, (y + 0.5) / size * 2 - 1
            directions = {'px': (1, -v, -u), 'nx': (-1, -v, u), 'py': (u, 1, v),
                          'ny': (u, -1, -v), 'pz': (u, -v, 1), 'nz': (-u, -v, -1)}
            face, u, v = locate(directions[face])
            x, y = math.floor((u + 1) * 0.5 * size), math.floor((v + 1) * 0.5 * size)
        offset = (max(0, min(size - 1, y)) * size + max(0, min(size - 1, x))) * 3
        return faces[face][offset:offset + 3]

    def sample(n):
        face, u, v = locate(n)
        x, y = (u + 1) * 0.5 * size - 0.5, (v + 1) * 0.5 * size - 0.5
        x0, y0 = math.floor(x), math.floor(y)
        tx, ty = x - x0, y - y0
        a, b, c, d = texel(face, x0, y0), texel(face, x0 + 1, y0), texel(face, x0, y0 + 1), texel(face, x0 + 1, y0 + 1)
        return tuple(((a[i] * (1 - tx) + b[i] * tx) * (1 - ty) + (c[i] * (1 - tx) + d[i] * tx) * ty) * exposure for i in range(3))
    return sample


def write_sky(output, width, source):
    """独立高清线性天空，复用 IBL 的辐射范围编码和周期边框协议。"""
    height = width // 2
    # 两遍采样，避免高清天空同时常驻数百万个 Python 浮点元组。
    radiance_range = 1.
    for y in range(height):
        for x in range(width):
            pixel = source(direction((x + 0.5) / width, (y + 0.5) / height))
            if any(not math.isfinite(c) or c < 0 for c in pixel):
                raise ValueError('天空辐射值必须为非负有限数值')
            radiance_range = max(radiance_range, *pixel)
    if not math.isfinite(radiance_range) or radiance_range > 1e30:
        raise ValueError('天空辐射值超出支持范围')
    encoded = bytearray()
    for y in range(height + 2):
        row = [source(direction((x + 0.5) / width, (max(0, min(height - 1, y - 1)) + 0.5) / height))
               for x in range(width)]
        for x in range(width + 2):
            pixel = row[(x - 1) % width]
            encoded.extend(round(max(0, min(1, c / radiance_range)) * 255) for c in pixel)
    write_png(output / 'sky.png', width + 2, height + 2, encoded)
    metadata = {'format': 'hxmaker-sky-1', 'encoding': 'linear-rgb-range',
                'width': width, 'height': height, 'radianceRange': radiance_range}
    (output / 'sky.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'已生成天空：{width} × {height}，辐射范围 {radiance_range:.3f}', flush=True)


def convolve(n, samples, source, diffuse=False):
    tangent, bitangent = basis(n)
    total, weight = [0., 0., 0.], 0.
    for local in samples:
        world = to_world(local, n, tangent, bitangent)
        if diffuse:
            incoming, cosine = world, 1.
        else:
            nh = max(dot(n, world), 0)
            incoming = tuple(2 * nh * world[i] - n[i] for i in range(3))
            cosine = max(dot(n, incoming), 0)
        if cosine > 0:
            radiance = source(incoming)
            for i in range(3):
                total[i] += radiance[i] * cosine
            weight += cosine
    return tuple(c / max(weight, 1e-8) for c in total)


def integrate_brdf(nv, roughness, samples):
    nv = max(nv, 0.001)
    view = (math.sqrt(max(0, 1 - nv * nv)), 0, nv)
    a2 = max(roughness, 0.045) ** 4
    scale, bias = 0., 0.
    for half in samples:
        vh = max(dot(view, half), 0)
        nl = 2 * vh * half[2] - nv
        if nl > 0:
            gv = nl * math.sqrt(nv * nv * (1 - a2) + a2)
            gl = nv * math.sqrt(nl * nl * (1 - a2) + a2)
            weight = 2 * nl * vh / max((gv + gl) * half[2], 1e-8)
            fresnel = (1 - vh) ** 5
            scale += (1 - fresnel) * weight
            bias += fresnel * weight
    return (scale / len(samples), bias / len(samples), 0.)


def write_png(path, width, height, pixels):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    raw = b''.join(b'\x00' + bytes(pixels[y * width * 3:(y + 1) * width * 3]) for y in range(height))
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
                     + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, help='2:1 HDR 或 PNG/JPEG 全景图；省略则生成示例摄影棚')
    parser.add_argument('--cube-dir', type=Path, help='六面图片目录，与 --input 互斥')
    parser.add_argument('--sky-width', type=int, default=0, help='高清天空有效宽度，16～4096 的偶数；默认 0 不输出天空')
    parser.add_argument('--sky-only', action='store_true', help='只生成天空，不计算 IBL')
    parser.add_argument('--output', type=Path, required=True, help='输出目录')
    parser.add_argument('--width', type=int, default=128, help='环境层宽度，默认 128')
    parser.add_argument('--levels', type=int, default=6, help='粗糙度层数，默认 6')
    parser.add_argument('--samples', type=int, default=128, help='每像素积分样本数，默认 128')
    parser.add_argument('--exposure', type=float, default=1., help='烘焙前线性亮度倍率')
    args = parser.parse_args()
    if not 16 <= args.width <= 512 or args.width % 2 or not 2 <= args.levels <= 10 or not 16 <= args.samples <= 2048:
        parser.error('宽度需为 16～512 的偶数，层数 2～10，样本数 16～2048')
    if not math.isfinite(args.exposure) or args.exposure <= 0:
        parser.error('曝光倍率必须是正有限数值')
    if args.input and args.cube_dir:
        parser.error('--input 与 --cube-dir 不能同时指定')
    if args.sky_width != 0 and (args.sky_width < 16 or args.sky_width > 4096 or args.sky_width % 2):
        parser.error('天空宽度需为 16～4096 的偶数')
    if args.sky_only and args.sky_width == 0:
        parser.error('--sky-only 需要设置 --sky-width')
    source = load_cube(args.cube_dir, args.exposure) if args.cube_dir else load_source(args.input, args.exposure)
    args.output.mkdir(parents=True, exist_ok=True)
    if args.sky_width:
        write_sky(args.output, args.sky_width, source)
    if args.sky_only:
        return
    width, height = args.width, args.width // 2
    points = sequence(args.samples)
    layers = []
    for level in range(args.levels + 1):
        diffuse = level == args.levels
        roughness = min(level / (args.levels - 1), 1)
        samples = ([(math.cos(2 * math.pi * u) * math.sqrt(v), math.sin(2 * math.pi * u) * math.sqrt(v), math.sqrt(1 - v))
                    for u, v in points] if diffuse else ggx_samples(roughness, points))
        print('生成漫反射环境光' if diffuse else f'生成反射层 {level + 1}/{args.levels}，粗糙度 {roughness:.2f}', flush=True)
        layers.append([source(direction((x + 0.5) / width, (y + 0.5) / height)) if level == 0 else
                       convolve(direction((x + 0.5) / width, (y + 0.5) / height), samples, source, diffuse)
                       for y in range(height) for x in range(width)])
    radiance_range = max(1., max(c for layer in layers for pixel in layer for c in pixel))
    if not math.isfinite(radiance_range):
        raise ValueError('辐射值超出有效数值范围')
    atlas_width = width + 2
    lut_offset = (height + 2) * len(layers)
    atlas_height = lut_offset + width + 2
    pixels = bytearray(atlas_width * atlas_height * 3)

    def put(x, y, color):
        offset = (y * atlas_width + x) * 3
        pixels[offset:offset + 3] = bytes(round(max(0, min(1, c)) * 255) for c in color)

    for level, layer in enumerate(layers):
        for y in range(height + 2):
            for x in range(width + 2):
                # 横向边框跨接全景接缝，纵向边框复制极点，防止粗糙度层间串色。
                source_x = (x - 1) % width
                source_y = max(0, min(height - 1, y - 1))
                put(x, level * (height + 2) + y, tuple(c / radiance_range for c in layer[source_y * width + source_x]))
    print('生成 BRDF 查找表', flush=True)
    lut = []
    for y in range(width):
        roughness = y / (width - 1)
        samples = ggx_samples(roughness, points)
        lut.extend(integrate_brdf(x / (width - 1), roughness, samples) for x in range(width))
    for y in range(width + 2):
        for x in range(width + 2):
            put(x, lut_offset + y, lut[max(0, min(width - 1, y - 1)) * width + max(0, min(width - 1, x - 1))])
    args.output.mkdir(parents=True, exist_ok=True)
    write_png(args.output / 'environment.png', atlas_width, atlas_height, pixels)
    metadata = {'format': 'hxmaker-ibl-1', 'layerWidth': width, 'layerHeight': height, 'levels': args.levels,
                'radianceRange': radiance_range, 'samples': args.samples, 'encoding': 'linear-rgb-range',
                'source': args.input.name if args.input else args.cube_dir.name if args.cube_dir else '程序生成摄影棚'}
    (args.output / 'environment.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'已生成 IBL 图集：{atlas_width} × {atlas_height}，辐射范围 {radiance_range:.3f}', flush=True)


if __name__ == '__main__':
    main()
