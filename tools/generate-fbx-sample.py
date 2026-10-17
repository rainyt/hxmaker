"""生成原创静态机器人资源；只写入文件，不调用模型加载器或执行验证。"""

import base64
import json
from pathlib import Path
import struct
import zlib


OUTPUT = Path(__file__).resolve().parents[1] / "samples/3d/fbx-model/Assets"
BASE_ID = 9007199254740993


def element(name, values=(), children=()):
    return (name, list(values), list(children))


def prop(name, values):
    kind = "Vector3D" if len(values) == 3 else "double"
    return element("P", [name, kind, "", "A", *values])


def properties(values):
    return element("Properties70", children=[prop(name, value) for name, value in values.items()])


def png():
    # 四个不透明色块，便于用户观察贴图方向。
    pixels = bytes([0, 255, 64, 64, 255, 64, 255, 64, 255, 0, 64, 64, 255, 255, 255, 220, 64, 255])

    def chunk(kind, payload):
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload))

    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 2, 2, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(pixels)) + chunk(b"IEND", b"")


def cube(width, depth, height):
    x, y, z = width / 2, depth / 2, height / 2
    points = [(-x, -y, -z), (x, -y, -z), (x, y, -z), (-x, y, -z), (-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z)]
    faces = [[0, 1, 5, 4], [2, 3, 7, 6], [1, 2, 6, 5], [3, 0, 4, 7], [4, 5, 6, 7], [3, 2, 1, 0]]
    normals = [(0, -1, 0), (0, 1, 0), (1, 0, 0), (-1, 0, 0), (0, 0, 1), (0, 0, -1)]
    return points, faces, normals, [0, 1, 0, 0, 1, 0]


def geometry(index, name, mesh):
    points, faces, normals, slots = mesh
    vertices = [component for point in points for component in point]
    polygons, normal_values, uv_values = [], [], []
    for face, normal in zip(faces, normals):
        polygons.extend(face[:-1] + [-face[-1] - 1])
        for i in range(len(face)):
            normal_values.extend(normal)
            uv_values.extend([(0, 0), (1, 0), (1, 1), (0, 1)][i % 4])

    def layer(kind, values, width):
        value_name = "Normals" if kind == "Normal" else "UV"
        return element("LayerElement" + kind, [0], [element("Version", [101]), element("Name", ["UVMap" if width == 2 else ""]),
            element("MappingInformationType", ["ByPolygonVertex"]), element("ReferenceInformationType", ["Direct"]),
            element(value_name, [values])])

    layers = [element("LayerElement", children=[element("Type", ["LayerElement" + kind]), element("TypedIndex", [0])])
              for kind in ("Normal", "UV", "Material")]
    return element("Geometry", [BASE_ID + 100 + index, "Geometry::" + name, "Mesh"], [
        element("Vertices", [vertices]), element("PolygonVertexIndex", [polygons]), layer("Normal", normal_values, 3), layer("UV", uv_values, 2),
        element("LayerElementMaterial", [0], [element("Version", [101]), element("Name", [""]),
            element("MappingInformationType", ["ByPolygon"]), element("ReferenceInformationType", ["IndexToDirect"]), element("Materials", [slots])]),
        element("Layer", [0], [element("Version", [100]), *layers])])


def build_document():
    visor = ([(-20, 0, -8), (20, 0, -8), (20, 0, 8), (-20, 0, 8)], [[0, 1, 2, 3]], [(0, -1, 0)], [0])
    emblem = ([(x, 0, z) for x, z in [(-15, -15), (15, -15), (15, -3), (-3, -3), (-3, 15), (-15, 15)]],
              [[0, 1, 2, 3, 4, 5]], [(0, -1, 0)], [0])
    pieces = [
        ("身体", 0, [0, 0, 110], cube(70, 40, 80), [0, 1]),
        ("头部", 1, [0, 0, 65], cube(55, 45, 45), [0, 1]),
        ("左腿", 0, [-22, 0, 35], cube(25, 30, 70), [0, 1]),
        ("右腿", 0, [22, 0, 35], cube(25, 30, 70), [0, 1]),
        ("左臂", 0, [-55, 0, 110], cube(22, 25, 70), [0, 1]),
        ("右臂", 0, [55, 0, 110], cube(22, 25, 70), [0, 1]),
        ("面罩", 2, [0, -24, 0], visor, [2]),
        ("凹多边形徽章", 1, [0, -21, 0], emblem, [1]),
    ]
    objects = [element("Model", [BASE_ID, "Model::机器人根节点", "Null"], [properties({"Lcl Rotation": [0, 0, 12], "InheritType": [1]})])]
    connections = [element("C", ["OO", BASE_ID, 0])]
    for i, (name, parent, translation, mesh, slots) in enumerate(pieces):
        transform = {"Lcl Translation": translation, "InheritType": [1]}
        if i in (4, 5):
            transform.update({"Lcl Rotation": [0, -10 if i == 4 else 10, 0], "RotationPivot": [0, 0, 30], "GeometricTranslation": [0, 2, 0]})
        objects.extend([element("Model", [BASE_ID + i + 1, "Model::" + name, "Mesh"], [properties(transform)]), geometry(i, name, mesh)])
        connections.extend([element("C", ["OO", BASE_ID + i + 1, BASE_ID + parent]),
                            element("C", ["OO", BASE_ID + 100 + i, BASE_ID + i + 1])])
        connections.extend(element("C", ["OO", BASE_ID + 200 + slot, BASE_ID + i + 1]) for slot in slots)
    for i, (name, color) in enumerate([("蓝色", [0.08, 0.28, 0.7]), ("金色", [0.95, 0.55, 0.08]), ("贴图", [1, 1, 1])]):
        objects.append(element("Material", [BASE_ID + 200 + i, "Material::" + name, ""], [element("ShadingModel", ["lambert"]),
            properties({"DiffuseColor": color, "DiffuseFactor": [1], "Opacity": [1]})]))
    image = png()
    objects.extend([element("Video", [BASE_ID + 301, "Video::四色图片", "Clip"], [element("Content", [image])]),
        element("Texture", [BASE_ID + 300, "Texture::面罩贴图", ""], [element("Type", ["TextureVideoClip"]),
            element("WrapModeU", [1]), element("WrapModeV", [1]), element("Properties70", children=[element("P", ["UVSet", "KString", "", "", "UVMap"])])])])
    connections.extend([element("C", ["OO", BASE_ID + 301, BASE_ID + 300]), element("C", ["OP", BASE_ID + 300, BASE_ID + 202, "DiffuseColor"])])
    settings = {"UpAxis": [2], "UpAxisSign": [1], "FrontAxis": [1], "FrontAxisSign": [1], "CoordAxis": [0], "CoordAxisSign": [1], "UnitScaleFactor": [1]}
    return [element("FBXHeaderExtension", children=[element("FBXHeaderVersion", [1003]), element("FBXVersion", [7400]), element("Creator", ["hxmaker 原创静态 FBX 示例"])]),
        element("GlobalSettings", children=[properties(settings)]), element("Objects", children=objects), element("Connections", children=connections)], pieces


def ascii_node(node, depth=0):
    name, values, children = node
    indent = "\t" * depth
    if len(values) == 1 and isinstance(values[0], list):
        items = ",".join(str(value) for value in values[0])
        return f"{indent}{name}: *{len(values[0])} {{\n{indent}\ta: {items}\n{indent}}}\n"
    encoded = []
    for value in values:
        if isinstance(value, bytes):
            value = base64.b64encode(value).decode("ascii")
        encoded.append(json.dumps(value, ensure_ascii=False) if isinstance(value, str) else str(value))
    line = indent + name + ": " + ",".join(encoded)
    return line + (" {\n" + "".join(ascii_node(child, depth + 1) for child in children) + indent + "}\n" if children else "\n")


def binary_property(value):
    if isinstance(value, str):
        data = value.encode("utf-8")
        return b"S" + struct.pack("<I", len(data)) + data
    if isinstance(value, bytes):
        return b"R" + struct.pack("<I", len(value)) + value
    if isinstance(value, list):
        integral = all(isinstance(item, int) for item in value)
        raw = struct.pack("<" + ("i" if integral else "d") * len(value), *value)
        packed = zlib.compress(raw)
        return (b"i" if integral else b"d") + struct.pack("<III", len(value), 1, len(packed)) + packed
    if isinstance(value, int):
        return b"L" + struct.pack("<q", value)
    return b"D" + struct.pack("<d", value)


def binary_node(node, offset, version):
    name, values, children = node
    tag = name.encode("utf-8")
    width = 25 if version >= 7500 else 13
    payload = b"".join(binary_property(value) for value in values)
    position = offset + width + len(tag) + len(payload)
    nested = bytearray()
    for child in children:
        encoded = binary_node(child, position, version)
        nested.extend(encoded)
        position += len(encoded)
    if children:
        nested.extend(bytes(width))
        position += width
    header = struct.pack("<QQQB" if version >= 7500 else "<IIIB", position, len(values), len(payload), len(tag))
    return header + tag + payload + nested


def glb(pieces):
    # 生成同一静态造型的 GLB 对照资源，未调用 FBX 导入器。
    import math

    document = {"asset": {"version": "2.0", "generator": "hxmaker 原创 FBX/GLB 对照示例"}, "scene": 0, "scenes": [{"nodes": []}],
                "nodes": [], "meshes": [], "materials": [], "bufferViews": [], "accessors": []}
    buffer = bytearray()

    def store(data):
        while len(buffer) % 4:
            buffer.append(0)
        view = len(document["bufferViews"])
        document["bufferViews"].append({"buffer": 0, "byteOffset": len(buffer), "byteLength": len(data)})
        buffer.extend(data)
        return view

    def accessor(values, width, integer=False):
        view = store(struct.pack("<" + ("I" if integer else "f") * len(values), *values))
        document["accessors"].append({"bufferView": view, "componentType": 5125 if integer else 5126,
                                      "count": len(values) // width, "type": {1: "SCALAR", 2: "VEC2", 3: "VEC3"}[width]})
        return len(document["accessors"]) - 1

    angle = math.radians(12) / 2
    document["nodes"].append({"name": "机器人根节点", "children": [], "rotation": [0, 0, math.sin(angle), math.cos(angle)]})
    for i, (name, parent, translation, mesh, slots) in enumerate(pieces):
        document["nodes"].append({"name": name, "translation": translation, "children": []})
        document["nodes"][parent]["children"].append(i + 1)
        if i in (4, 5):
            angle = math.radians(-10 if i == 4 else 10)
            document["nodes"][-1]["rotation"] = [0, math.sin(angle / 2), 0, math.cos(angle / 2)]
            document["nodes"][-1]["translation"] = [translation[0] - math.sin(angle) * 30, translation[1], translation[2] + 30 - math.cos(angle) * 30]
    for i, (name, parent, translation, mesh, slots) in enumerate(pieces):
        points, faces, normals, face_slots = mesh
        groups = {}
        for face_index, (face, normal, slot) in enumerate(zip(faces, normals, face_slots)):
            group = groups.setdefault(slots[slot], {"p": [], "n": [], "uv": [], "i": []})
            start = len(group["p"]) // 3
            for corner, point in enumerate(face):
                group["p"].extend(points[point])
                group["n"].extend(normal)
                u, v = [(0, 0), (1, 0), (1, 1), (0, 1)][corner % 4]
                group["uv"].extend([u, 1 - v])
            triangles = [0, 1, 2, 0, 2, 3, 0, 3, 5, 3, 4, 5] if len(face) == 6 else [0, 1, 2, 0, 2, 3]
            group["i"].extend(start + index for index in triangles)
        primitives = [{"attributes": {"POSITION": accessor(g["p"], 3), "NORMAL": accessor(g["n"], 3), "TEXCOORD_0": accessor(g["uv"], 2)},
                       "indices": accessor(g["i"], 1, True), "material": slot} for slot, g in groups.items()]
        document["meshes"].append({"primitives": primitives})
        helper = {"name": name + " / 网格 " + str(i), "mesh": i}
        if i in (4, 5):
            helper["translation"] = [0, 2, 0]
        document["nodes"][i + 1]["children"].append(len(document["nodes"]))
        document["nodes"].append(helper)
    document["scenes"][0]["nodes"] = [len(document["nodes"])]
    document["nodes"].append({"name": "坐标归一化", "children": [0], "matrix": [0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, 0.01, 0, 0, 0, 0, 0, 1]})
    for name, color in [("蓝色", [0.08, 0.28, 0.7, 1]), ("金色", [0.95, 0.55, 0.08, 1]), ("贴图", [1, 1, 1, 1])]:
        document["materials"].append({"name": name, "doubleSided": True, "pbrMetallicRoughness": {"baseColorFactor": color, "metallicFactor": 0, "roughnessFactor": 1}})
    document["images"] = [{"bufferView": store(png()), "mimeType": "image/png"}]
    document["textures"] = [{"source": 0, "sampler": 0}]
    document["samplers"] = [{"wrapS": 33071, "wrapT": 33071, "magFilter": 9729, "minFilter": 9729}]
    document["materials"][2]["pbrMetallicRoughness"]["baseColorTexture"] = {"index": 0}
    document["buffers"] = [{"byteLength": len(buffer)}]
    metadata = json.dumps(document, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    metadata += b" " * (-len(metadata) % 4)
    buffer.extend(bytes(-len(buffer) % 4))
    return struct.pack("<III", 0x46546C67, 2, 28 + len(metadata) + len(buffer)) + struct.pack("<II", len(metadata), 0x4E4F534A) + metadata + struct.pack("<II", len(buffer), 0x004E4942) + buffer


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    document, pieces = build_document()
    (OUTPUT / "robot-ascii.fbx").write_text("; FBX 7.4.0 project file\n; hxmaker 原创静态机器人示例\n" + "".join(ascii_node(node) for node in document), encoding="utf-8")
    for version in (7400, 7500):
        data = bytearray(b"Kaydara FBX Binary  \x00\x1a\x00" + struct.pack("<I", version))
        for node in document:
            if node[0] == "FBXHeaderExtension":
                node = element(node[0], node[1], [element("FBXVersion", [version]) if entry[0] == "FBXVersion" else entry for entry in node[2]])
            data.extend(binary_node(node, len(data), version))
        data.extend(bytes(25 if version >= 7500 else 13))
        (OUTPUT / f"robot-binary-{version}.fbx").write_bytes(data)
    (OUTPUT / "robot.glb").write_bytes(glb(pieces))
    (OUTPUT / "checker.png").write_bytes(png())
    print("已生成 FBX ASCII、二进制 7400/7500、GLB 对照及贴图资源；未执行加载或验证。")


if __name__ == "__main__":
    main()
