package hx.formats;

import haxe.io.Bytes;
import hx.formats.gltf.GlbImporter;
import hx.formats.fbx.FbxImporter;
import hx.model.ModelAssetData;

/** 模型内容识别与导入分发；业务加载接口不暴露具体源格式。 */
class ModelImporter {
	public static function importBytes(bytes:Bytes):ModelAssetData {
		if (bytes == null || bytes.length < 4) throw "模型文件为空或文件头不完整";
		if (bytes.getInt32(0) == 0x46546c67) return GlbImporter.importBytes(bytes);
		if (bytes.length >= 23 && bytes.getString(0, 20) == "Kaydara FBX Binary  ")
			return FbxImporter.importBytes(bytes);
		// 只匹配 ASCII 关键字，避免探测窗口截断中文 UTF-8 字符。
		var buffer = new StringBuf();
		for (i in 0...Std.int(Math.min(bytes.length, 4096))) buffer.addChar(bytes.get(i));
		var prefix = buffer.toString();
		if (prefix.indexOf("FBXHeaderExtension:") >= 0) return FbxImporter.importBytes(bytes);
		throw "无法识别模型格式，当前支持 GLB 和 FBX";
	}
}
