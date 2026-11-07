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
	/** 默认仅按源图修改时间复用缓存；开启后执行原有内容哈希和输出完整性校验。 */
	var ?verifyHashes:Bool;
	/** 强制重新编码；修改编码器或编码参数后，使用此选项刷新未修改的源图。 */
	var ?force:Bool;
}
