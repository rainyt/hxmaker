package hx.formats.fbx;

import haxe.Int64;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.zip.InflateImpl;
import hx.formats.fbx.FbxDocument.FbxElement;
import hx.formats.fbx.FbxDocument.FbxValue;

private typedef FbxToken = {var kind:String; var text:String;}

/** 有界 FBX 7.x ASCII/二进制语法解析器，不依赖浏览器、原生程序或第三方渲染库。 */
class FbxParser {
	private static inline var MAX_FILE:Int = 64 * 1024 * 1024;
	private static inline var MAX_ARRAY_VALUES:Int = 4000000;
	private static inline var MAX_EXPANDED_BYTES:Int = 128 * 1024 * 1024;
	private var bytes:Bytes;
	private var position:Int = 0;
	private var version:Int;
	private var elementCount:Int = 0;
	private var valueCount:Int = 0;
	private var arrayValues:Int = 0;
	private var expandedBytes:Int = 0;
	private var text:String;
	private var token:FbxToken;

	private function new(bytes:Bytes) this.bytes = bytes;

	public static function parse(bytes:Bytes):FbxDocument {
		if (bytes == null || bytes.length < 4 || bytes.length > MAX_FILE) throw "FBX 文件长度无效或超过 64 MiB 上限";
		return new FbxParser(bytes).read();
	}

	private function read():FbxDocument {
		var nodes:Array<FbxElement> = [];
		if (bytes.length >= 23 && bytes.getString(0, 20) == "Kaydara FBX Binary  ") {
			need(27, bytes.length);
			if (bytes.get(20) != 0 || bytes.get(21) != 26 || bytes.get(22) != 0) throw "FBX 二进制文件头无效";
			version = bytes.getInt32(23);
			checkVersion();
			position = 27;
			while (true) {
				var node = binaryNode(bytes.length, 0);
				if (node == null) break;
				nodes.push(node);
			}
		} else {
			text = bytes.toString();
			if (StringTools.startsWith(text, "\ufeff")) text = text.substr(1);
			nodes = textNodes(0);
			if (peek().kind != "end") throw "FBX ASCII 存在多余的右括号";
			var header = find(nodes, "FBXHeaderExtension"), entry = header == null ? null : find(header.children, "FBXVersion");
			if (entry == null || entry.properties.length != 1) throw "FBX ASCII 缺少 FBXVersion";
			var declaredVersion = number(entry.properties[0]);
			if (!Math.isFinite(declaredVersion) || declaredVersion != Math.floor(declaredVersion)) throw "FBX ASCII 版本必须为整数";
			version = Std.int(declaredVersion);
			checkVersion();
		}
		return {version: version, nodes: nodes};
	}

	private function checkVersion():Void {
		if (version < 7000 || version >= 8000) throw "FBX 当前只支持 7.x 文件，实际版本：" + version;
	}

	private function binaryNode(limit:Int, depth:Int):FbxElement {
		if (depth > 128 || ++elementCount > 100000) throw "FBX 语法节点数量或嵌套深度超限";
		need(version >= 7500 ? 25 : 13, limit);
		var end = sizedInt(limit), count = sizedInt(limit), length = sizedInt(limit), nameLength = byte(limit);
		if (end == 0) {
			if (count != 0 || length != 0 || nameLength != 0) throw "FBX 空节点记录无效";
			return null;
		}
		if (end <= position || end > limit || count > 1000000) throw "FBX 节点边界或属性数量无效";
		var name = string(nameLength, end), start = position;
		if (length > end - start) throw "FBX 属性数据越过节点边界";
		var properties:Array<FbxValue> = [], propertyEnd = start + length;
		for (_ in 0...count) properties.push(binaryValue(propertyEnd));
		if (position != propertyEnd) throw "FBX 属性长度与声明不符";
		var children:Array<FbxElement> = [];
		while (position < end) {
			var child = binaryNode(end, depth + 1);
			if (child == null) {
				if (position != end) throw "FBX 子节点结束标记位置无效";
				break;
			}
			children.push(child);
		}
		return {name: name, properties: properties, children: children};
	}

	private function binaryValue(limit:Int):FbxValue {
		if (++valueCount > 1000000) throw "FBX 属性数量超限";
		var type = byte(limit);
		return switch (type) {
			case 89:
				need(2, limit);
				var value = bytes.getUInt16(position); position += 2;
				Integer(Std.string(value >= 32768 ? value - 65536 : value));
			case 67: Number(byte(limit) == 0 ? 0. : 1.);
			case 73:
				need(4, limit); var value = bytes.getInt32(position); position += 4; Integer(Std.string(value));
			case 76:
				need(8, limit); var value = bytes.getInt64(position); position += 8; Integer(Int64.toStr(value));
			case 70:
				need(4, limit); var value = bytes.getFloat(position); position += 4; Number(value);
			case 68:
				need(8, limit); var value = bytes.getDouble(position); position += 8; Number(value);
			case 83: Text(string(unsignedInt(limit), limit));
			case 82:
				var length = unsignedInt(limit); need(length, limit);
				var value = bytes.sub(position, length); position += length; Binary(value);
			case 102, 100, 108, 105, 98, 99: Numbers(binaryArray(type, limit));
			default: throw "FBX 属性类型不支持：" + String.fromCharCode(type);
		};
	}

	private function binaryArray(type:Int, limit:Int):Array<Float> {
		var count = unsignedInt(limit), encoding = unsignedInt(limit), size = unsignedInt(limit);
		var width = type == 100 || type == 108 ? 8 : type == 98 || type == 99 ? 1 : 4;
		arrayValues += count;
		if (count > MAX_ARRAY_VALUES || arrayValues > MAX_ARRAY_VALUES || count > Std.int(MAX_EXPANDED_BYTES / width))
			throw "FBX 数组数量超限";
		var expected = count * width;
		expandedBytes += expected;
		if (expandedBytes > MAX_EXPANDED_BYTES) throw "FBX 数组展开内存超限";
		need(size, limit);
		var input = bytes.sub(position, size); position += size;
		var data:Bytes;
		if (encoding == 0) {
			if (size != expected) throw "FBX 未压缩数组长度不符";
			data = input;
		} else if (encoding == 1) {
			// 固定输出容量并额外探测一个字节，不能用无限制的解压缩接口。
			var stream = new BytesInput(input), inflate = new InflateImpl(stream);
			data = Bytes.alloc(expected);
			if (inflate.readBytes(data, 0, expected) != expected || inflate.readBytes(Bytes.alloc(1), 0, 1) != 0
				|| stream.position != input.length) throw "FBX 压缩数组长度或压缩流无效";
		} else throw "FBX 数组压缩方式不支持";
		var result:Array<Float> = [];
		for (i in 0...count) {
			var at = i * width;
			var value:Float = switch (type) {
				case 102: data.getFloat(at);
				case 100: data.getDouble(at);
				case 105: data.getInt32(at);
				case 108:
					var value = data.getInt64(at);
					var result = value.high * 4294967296. + (value.low < 0 ? value.low + 4294967296. : value.low);
					if (Math.abs(result) > 9007199254740991.) throw "FBX 数值数组包含无法精确表示的 64 位整数";
					result;
				case 99: data.get(at) >= 128 ? data.get(at) - 256 : data.get(at);
				default: data.get(at);
			};
			if (!Math.isFinite(value)) throw "FBX 数组包含非有限数值";
			result.push(value);
		}
		return result;
	}

	private function textNodes(depth:Int):Array<FbxElement> {
		if (depth > 128) throw "FBX ASCII 嵌套过深";
		var result:Array<FbxElement> = [];
		while (peek().kind != "end" && peek().kind != "}") {
			if (++elementCount > 100000) throw "FBX ASCII 节点数量超限";
			var name = take();
			if (name.kind != "node") throw "FBX ASCII 需要节点名称，位置：" + position;
			var properties:Array<FbxValue> = [], children:Array<FbxElement> = [];
			while (true) {
				var value = peek();
				if (value.kind == "node" || value.kind == "}" || value.kind == "end") break;
				take();
				switch (value.kind) {
					case ",": continue;
					case "{":
						children = textNodes(depth + 1); expect("}");
					case "*":
						var countToken = take();
						if (countToken.kind != "number") throw "FBX ASCII 数组缺少长度";
						var size = Std.parseFloat(countToken.text);
						if (!Math.isFinite(size) || size < 0 || size != Math.floor(size) || size > MAX_ARRAY_VALUES)
							throw "FBX ASCII 数组长度无效";
						var count = Std.int(size); arrayValues += count;
						if (arrayValues > MAX_ARRAY_VALUES) throw "FBX ASCII 数组数量超限";
						expect("{"); var marker = take();
						if (marker.kind != "node" || marker.text != "a") throw "FBX ASCII 数组缺少 a 字段";
						var values:Array<Float> = [];
						while (peek().kind != "}") {
							var item = take();
							if (item.kind == ",") continue;
							if (item.kind != "number" || values.length >= count) throw "FBX ASCII 数组内容无效";
							var number = Std.parseFloat(item.text);
							if (!Math.isFinite(number)) throw "FBX ASCII 数组包含非有限数值";
							values.push(number);
						}
						expect("}");
						if (values.length != count) throw "FBX ASCII 数组长度与声明不符";
						properties.push(Numbers(values));
					case "number":
						properties.push(~/^[+-]?[0-9]+$/.match(value.text) ? Integer(value.text) : Number(Std.parseFloat(value.text)));
					case "string", "word": properties.push(Text(value.text));
					default: throw "FBX ASCII 属性内容无效";
				}
				if (++valueCount > 1000000) throw "FBX ASCII 属性数量超限";
				if (value.kind == "{" || value.kind == "*") break;
			}
			result.push({name: name.text, properties: properties, children: children});
		}
		return result;
	}

	private function peek():FbxToken {
		if (token == null) token = lex();
		return token;
	}

	private function take():FbxToken {
		var result = peek(); token = null; return result;
	}

	private function expect(kind:String):Void {
		if (take().kind != kind) throw "FBX ASCII 需要 " + kind + "，位置：" + position;
	}

	private function lex():FbxToken {
		while (position < text.length) {
			var c = text.charCodeAt(position);
			if (c == 32 || c == 9 || c == 10 || c == 13) { position++; continue; }
			if (c == 59) { while (position < text.length && text.charCodeAt(position) != 10) position++; continue; }
			break;
		}
		if (position == text.length) return {kind: "end", text: ""};
		var c = text.charAt(position++);
		if (c == "{" || c == "}" || c == "," || c == "*") return {kind: c, text: c};
		if (c == '"') {
			var buffer = new StringBuf(), closed = false;
			while (position < text.length) {
				var character = text.charAt(position++);
				if (character == '"') { closed = true; break; }
				if (character == "\n" || character == "\r") throw "FBX ASCII 字符串未闭合";
				if (character == "\\" && position < text.length && (text.charAt(position) == '"' || text.charAt(position) == "\\"))
					character = text.charAt(position++);
				buffer.add(character);
			}
			if (!closed) throw "FBX ASCII 字符串未闭合";
			return {kind: "string", text: buffer.toString()};
		}
		var start = position - 1;
		while (position < text.length) {
			var character = text.charAt(position);
			if (character == ":" || character == "," || character == "{" || character == "}" || character == ";"
				|| character == " " || character == "\n" || character == "\r" || character == "\t") break;
			position++;
		}
		var value = text.substring(start, position);
		while (position < text.length && (text.charAt(position) == " " || text.charAt(position) == "\t")) position++;
		if (position < text.length && text.charAt(position) == ":") { position++; return {kind: "node", text: value}; }
		if (~/^[+-]?(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$/.match(value)) return {kind: "number", text: value};
		if (value.length == 0) throw "FBX ASCII 含有无法识别的字符";
		return {kind: "word", text: value};
	}

	private function byte(limit:Int):Int { need(1, limit); return bytes.get(position++); }

	private function unsignedInt(limit:Int):Int {
		need(4, limit); var value = bytes.getInt32(position); position += 4;
		if (value < 0) throw "FBX 长度超过支持范围";
		return value;
	}

	private function sizedInt(limit:Int):Int {
		var value = unsignedInt(limit);
		if (version >= 7500 && unsignedInt(limit) != 0) throw "FBX 64 位偏移超过支持范围";
		return value;
	}

	private function string(length:Int, limit:Int):String {
		need(length, limit); var result = bytes.getString(position, length); position += length; return result;
	}

	private function need(length:Int, limit:Int):Void {
		if (length < 0 || position > limit || length > limit - position) throw "FBX 文件数据越界，位置：" + position;
	}

	private static function find(nodes:Array<FbxElement>, name:String):FbxElement {
		for (node in nodes) if (node.name == name) return node;
		return null;
	}

	private static function number(value:FbxValue):Float {
		return switch (value) { case Integer(text): Std.parseFloat(text); case Number(value): value; default: throw "FBX 数值类型无效"; };
	}
}
