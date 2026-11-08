package hx.assets.astc;

/** 编译期和运行时共用的清单结构，不包含本机文件系统路径。 */
typedef ASTCManifestData = {
	var schemaVersion:Int;
	var prefix:String;
	var revision:String;
	var files:Array<String>;
}
