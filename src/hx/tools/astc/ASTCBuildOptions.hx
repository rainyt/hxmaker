package hx.tools.astc;

/** ASTC 增量构建选项；未配置时沿用 6×6、透明预乘和高质量编码。 */
typedef ASTCBuildOptions = {
	var ?output:String;
	var ?encoder:String;
	var ?block:String;
	var ?quality:String;
	var ?alphaPremultiply:Bool;
	var ?strict:Bool;
	var ?verifyHashes:Bool;
	var ?force:Bool;
}
