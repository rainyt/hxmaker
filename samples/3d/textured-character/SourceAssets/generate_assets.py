#!/usr/bin/env python3
"""生成原创机器人、三张校准贴图及骨骼动画；仅使用 Python 标准库。"""
import argparse
import json
import math
import struct
import zlib
from pathlib import Path

parser = argparse.ArgumentParser(description='生成贴图动画机器人资源')
parser.add_argument('--output-root', type=Path, help='可选输出示例目录，默认使用当前示例')
parser.add_argument('--name', default='robot', help='GLB 文件名，不含扩展名')
parser.add_argument('--subdivisions', type=int, default=1, help='每个盒子表面的网格细分数，1～16')
parser.add_argument('--all-blended', action='store_true', help='让所有网格都使用双关节权重')
parser.add_argument('--no-source-images', action='store_true', help='不另存 PNG 源文件')
args = parser.parse_args()
if not 1 <= args.subdivisions <= 16:
    parser.error('细分数必须在 1～16 之间')
if not args.name or any(c not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_' for c in args.name):
    parser.error('文件名只允许英文字母、数字、短横线和下划线')
ROOT = args.output_root.resolve() if args.output_root else Path(__file__).resolve().parents[1]
OUT = ROOT / 'Assets'
SOURCES = ROOT / 'SourceAssets'
OUT.mkdir(parents=True, exist_ok=True)


def png(size, pixel):
    """PNG 按从上到下的行顺序保存，标记用于检查 UV 方向。"""
    def chunk(tag, value):
        return struct.pack('>I', len(value)) + tag + value + struct.pack('>I', zlib.crc32(tag + value) & 0xffffffff)
    rows = b''.join(b'\0' + bytes(channel for x in range(size) for channel in pixel(x, y)) for y in range(size))
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(rows, 9)) + chunk(b'IEND', b'')


def body_pixel(x, y):
    if x < 14 and y < 14:
        return (255, 64, 100, 255)
    if x < 14 and y >= 114:
        return (64, 255, 160, 255)
    if min(x, y, 127-x, 127-y) < 5:
        return (14, 35, 60, 255)
    if (x-12) % 32 < 3 or (y-12) % 32 < 3:
        return (40, 88, 122, 255)
    if 25 < x < 103 and 38 < y < 89:
        if min(x-25, 103-x, y-38, 89-y) < 4:
            return (110, 225, 244, 255)
        if 44 < y < 55 and 34 < x < 94:
            return (244, 188, 70, 255)
        return (19, 52, 82, 255)
    return (45 + (x//16 % 2)*12, 132 + (y//16 % 2)*10, 180, 255)


def screen_pixel(x, y):
    if min(x, y, 127-x, 127-y) < 7:
        return (36, 58, 78, 255)
    if 26 <= y <= 61 and (19 <= x <= 46 or 81 <= x <= 108):
        return (115, 255, 233, 255)
    if 86 <= y <= 95 and 39 <= x <= 89:
        return (255, 193, 75, 255)
    if 15 <= x <= 22 and 16 <= y <= 22:
        return (255, 64, 100, 255)
    return (8, 20 + y % 4, 35, 255)


def limb_pixel(x, y):
    if min(x, y, 63-x, 63-y) < 4:
        return (57, 47, 43, 255)
    if (x+y)//9 % 2 == 0 and 18 < y < 46:
        return (65, 68, 67, 255)
    if y % 16 < 2:
        return (255, 218, 124, 255)
    return (235, 146, 51, 255)


images = [('body', png(128, body_pixel)), ('screen', png(128, screen_pixel)), ('limbs', png(64, limb_pixel))]
if not args.no_source_images:
    SOURCES.mkdir(parents=True, exist_ok=True)
    for name, data in images:
        (SOURCES / (name + '.png')).write_bytes(data)

binary = bytearray()
views, accessors, meshes, nodes = [], [], [], []


def append_view(data, target=None):
    while len(binary) % 4:
        binary.append(0)
    view = {'buffer': 0, 'byteOffset': len(binary), 'byteLength': len(data)}
    if target is not None:
        view['target'] = target
    binary.extend(data)
    views.append(view)
    return len(views)-1


def accessor(values, kind, component=5126, bounds=False):
    width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[kind]
    encoding = {5126: 'f', 5123: 'H', 5121: 'B'}[component]
    view = append_view(struct.pack('<' + encoding*len(values), *values))
    item = {'bufferView': view, 'componentType': component, 'count': len(values)//width, 'type': kind}
    if bounds:
        item['min'] = [min(values[i::width]) for i in range(width)]
        item['max'] = [max(values[i::width]) for i in range(width)]
    accessors.append(item)
    return len(accessors)-1


# 关节以模型空间位置声明，节点中保存父级相对位移。
joints, rest, joint_parents = [], [], []
def joint(name, position, parent=None):
    index = len(nodes)
    relative = position if parent is None else tuple(position[i]-rest[parent][i] for i in range(3))
    nodes.append({'name': name, 'translation': list(relative)})
    joints.append(index)
    rest.append(position)
    joint_parents.append(parent)
    if parent is not None:
        nodes[joints[parent]].setdefault('children', []).append(index)
    return len(joints)-1


hips = joint('Hips', (0, 1.2, 0))
spine = joint('Spine', (0, 1.8, 0), hips)
head = joint('Head', (0, 2.6, 0), spine)
arms, legs = [], []
for sign, side in [(-1, 'L'), (1, 'R')]:
    shoulder = joint('Shoulder.' + side, (sign*.78, 2.25, 0), spine)
    elbow = joint('Elbow.' + side, (sign*.78, 1.65, 0), shoulder)
    wrist = joint('Wrist.' + side, (sign*.78, 1.13, 0), elbow)
    arms.append((shoulder, elbow, wrist))
    hip = joint('Hip.' + side, (sign*.28, 1.15, 0), hips)
    knee = joint('Knee.' + side, (sign*.28, .65, 0), hip)
    ankle = joint('Ankle.' + side, (sign*.28, .15, 0), knee)
    legs.append((hip, knee, ankle))


def box(name, center, dimensions, material, influence, blend=None):
    """每面拆分顶点以保留硬边；正面朝 +Z，UV 原点位于图片左上。"""
    faces = [((0, 0, 1), [(0,0,1),(1,0,1),(1,1,1),(0,1,1)]),
             ((0, 0,-1), [(1,0,0),(0,0,0),(0,1,0),(1,1,0)]),
             ((1, 0, 0), [(1,0,1),(1,0,0),(1,1,0),(1,1,1)]),
             ((-1,0, 0), [(0,0,0),(0,0,1),(0,1,1),(0,1,0)]),
             ((0, 1, 0), [(0,1,1),(1,1,1),(1,1,0),(0,1,0)]),
             ((0,-1, 0), [(0,0,0),(1,0,0),(1,0,1),(0,0,1)])]
    positions, normals, uvs, indices, weights, joint_ids = [], [], [], [], [], []
    def emit(corner, uv, normal):
        position = [center[i] + (corner[i]-.5)*dimensions[i] for i in range(3)]
        positions.extend(position)
        normals.extend(normal)
        uvs.extend(uv)
        if blend is None:
            if args.all_blended:
                other = joint_parents[influence]
                if other is None:
                    other = spine
                joint_ids.extend([influence, other, 0, 0])
                weights.extend([.8, .2, 0, 0])
            else:
                joint_ids.extend([influence, 0, 0, 0])
                weights.extend([1, 0, 0, 0])
        else:
            # 衣甲中部受两关节共同影响，覆盖实际多权重 CPU 蒙皮路径。
            other, lower, upper = blend
            amount = max(0, min(1, (position[1]-lower)/(upper-lower)))
            joint_ids.extend([influence, other, 0, 0])
            weights.extend([amount, 1-amount, 0, 0])
    for normal, corners in faces:
        offset = len(positions)//3
        n = args.subdivisions
        if n == 1:
            # 默认生成顺序保持不变，已有示例的资产字节不因可选压力参数改变。
            for corner, uv in zip(corners, [(0,1),(1,1),(1,0),(0,0)]):
                emit(corner, uv, normal)
            indices.extend([offset,offset+1,offset+2,offset,offset+2,offset+3])
        else:
            for iy in range(n+1):
                for ix in range(n+1):
                    u, v = ix/n, iy/n
                    corner = [(1-u)*(1-v)*corners[0][i] + u*(1-v)*corners[1][i]
                              + u*v*corners[2][i] + (1-u)*v*corners[3][i] for i in range(3)]
                    emit(corner, (u,1-v), normal)
            for iy in range(n):
                for ix in range(n):
                    a = offset+iy*(n+1)+ix
                    indices.extend([a,a+1,a+n+2,a,a+n+2,a+n+1])
    primitive = {'attributes': {'POSITION': accessor(positions,'VEC3',bounds=True), 'NORMAL': accessor(normals,'VEC3'),
                 'TEXCOORD_0': accessor(uvs,'VEC2'), 'JOINTS_0': accessor(joint_ids,'VEC4',5121), 'WEIGHTS_0': accessor(weights,'VEC4')},
                 'indices': accessor(indices,'SCALAR',5123), 'material': material}
    meshes.append({'name': name, 'primitives': [primitive]})
    nodes.append({'name': name, 'mesh': len(meshes)-1, 'skin': 0})


box('Torso', (0,1.95,0), (1.05,1,.66), 0, spine, (hips,1.2,2.7))
box('Belt', (0,1.24,0), (.83,.27,.58), 2, hips)
box('HeadShell', (0,2.8,0), (.91,.7,.7), 0, head)
box('FaceScreen', (0,2.83,.363), (.77,.48,.035), 1, head)
for sign, side, arm, leg in zip([-1,1],['L','R'],arms,legs):
    shoulder, elbow, wrist = arm
    hip, knee, ankle = leg
    box('UpperArm.'+side, (sign*.78,1.95,0), (.33,.6,.35), 2, shoulder)
    box('Forearm.'+side, (sign*.78,1.39,0), (.38,.52,.4), 0, elbow)
    box('Hand.'+side, (sign*.78,1.01,.04), (.32,.28,.37), 2, wrist)
    box('Thigh.'+side, (sign*.28,.9,0), (.37,.5,.4), 0, hip)
    box('Shin.'+side, (sign*.28,.4,0), (.34,.5,.37), 2, knee)
    box('Foot.'+side, (sign*.28,.115,.12), (.4,.23,.64), 2, ankle)

inverse = []
for x,y,z in rest:
    inverse.extend([1,0,0,0, 0,1,0,0, 0,0,1,0, -x,-y,-z,1])
skins = [{'name':'RobotRig', 'joints':joints, 'skeleton':joints[hips], 'inverseBindMatrices':accessor(inverse,'MAT4')}]


def quat_x(angle):
    return [math.sin(angle/2),0,0,math.cos(angle/2)]


def make_animation(name, duration, walking):
    times = [duration*i/24 for i in range(25)]
    time_accessor = accessor(times,'SCALAR',bounds=True)
    samplers, channels = [], []
    def track(target, path, values, kind):
        samplers.append({'input':time_accessor,'output':accessor(values,kind),'interpolation':'LINEAR'})
        channels.append({'sampler':len(samplers)-1,'target':{'node':joints[target],'path':path}})
    for side, (shoulder, elbow, wrist), (hip, knee, ankle) in zip([-1,1],arms,legs):
        for bone, amplitude, phase in [(shoulder,.6 if walking else .06,0),(elbow,.23 if walking else .04,.5),
                                        (hip,-.52 if walking else .02,0),(knee,.34 if walking else .02,.7)]:
            values = []
            for t in times:
                angle = side*amplitude*math.sin(t/duration*math.tau+phase)
                if bone == knee and walking:
                    angle = abs(angle)
                values.extend(quat_x(angle))
            track(bone,'rotation',values,'VEC4')
    values = []
    for t in times:
        values.extend([0,1.2 + (.035 if walking else .018)*math.sin(t/duration*math.tau*(2 if walking else 1)),0])
    track(hips,'translation',values,'VEC3')
    values = []
    for t in times:
        values.extend(quat_x((.08 if walking else .035)*math.sin(t/duration*math.tau)))
    track(spine,'rotation',values,'VEC4')
    return {'name':name,'samplers':samplers,'channels':channels}


animations = [make_animation('Idle',2.0,False),make_animation('Walk',1.0,True)]
image_entries = [{'name':name,'bufferView':append_view(data),'mimeType':'image/png'} for name,data in images]
factors = [[.8,.95,1,1], [1,1,1,1], [1,.9,.75,1]]
materials = [{'name':name,'doubleSided':True,'pbrMetallicRoughness':{'baseColorFactor':factors[i],
              'baseColorTexture':{'index':i},'metallicFactor':0,'roughnessFactor':.8}} for i,name in enumerate(['BlueArmor','FaceDisplay','OrangeJoints'])]
mesh_nodes = [i for i,n in enumerate(nodes) if 'mesh' in n]
document = {'asset':{'version':'2.0','generator':'hxmaker 原创程序化机器人资源生成器'},'scene':0,
            'scenes':[{'name':'Robot','nodes':[joints[hips]]+mesh_nodes}], 'nodes':nodes,'meshes':meshes,'skins':skins,
            'animations':animations,'materials':materials,'images':image_entries,
            'samplers':[{'wrapS':33071,'wrapT':33071,'magFilter':9729,'minFilter':9729}],
            'textures':[{'source':i,'sampler':0} for i in range(len(images))],
            'bufferViews':views,'accessors':accessors,'buffers':[{'byteLength':len(binary)}]}
encoded = json.dumps(document,ensure_ascii=False,separators=(',',':')).encode('utf-8')
encoded += b' ' * (-len(encoded)%4)
binary.extend(b'\0' * (-len(binary)%4))
glb = struct.pack('<III',0x46546c67,2,28+len(encoded)+len(binary)) + struct.pack('<II',len(encoded),0x4e4f534a) + encoded + struct.pack('<II',len(binary),0x004e4942) + binary
(OUT/(args.name+'.glb')).write_bytes(glb)
print('已生成 Assets/'+args.name+'.glb：',len(glb),'字节，',len(meshes),'网格，',len(joints),'关节，',192*args.subdivisions**2,'三角形，3 张内嵌 PNG，Idle / Walk 动画。')
