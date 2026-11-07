package hx.tools.astc;

/** ASTC 增量构建选项；未配置时沿用 6×6、透明预乘和高质量编码。 */
typedef ASTCBuildOptions = {
	var ?output:String;
	var ?encoder:String;
	var ?block:String;
	var ?quality:String;
	var ?alphaPremultiply:Bool;
	/** 是否对 ASTC 文件进行外层 zlib 压缩，默认关闭；扩展名保持 .astc。 */
	var ?zlib:Bool;
	/** zlib 压缩等级，范围为 0～9，默认 9；仅在 zlib 开启时生效。 */
	var ?zlibLevel:Int;
	var ?strict:Bool;
	var ?verifyHashes:Bool;
	var ?force:Bool;
}
