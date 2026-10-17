package hx.formats.fbx;

import haxe.io.Bytes;

/** FBX 语法树；仅存在于导入阶段，不进入运行时模型资产。 */
typedef FbxDocument = {
	var version:Int;
	var nodes:Array<FbxElement>;
}

typedef FbxElement = {
	var name:String;
	var properties:Array<FbxValue>;
	var children:Array<FbxElement>;
}

/** 对象标识保留十进制整数文本，避免 JS 的 Float 丢失 64 位 ID。 */
enum FbxValue {
	Integer(value:String);
	Number(value:Float);
	Text(value:String);
	Numbers(values:Array<Float>);
	Binary(bytes:Bytes);
}
