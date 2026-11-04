package hx.assets;

import haxe.io.Bytes;

/** 与渲染后端无关的原始二维 ASTC 文件校验。 */
class ASTCFormat {
	/** 检查文件头、压缩块、尺寸及完整数据长度，拒绝截断文件和错误页。 */
	public static function isValid(bytes:Bytes, ?fileSize:Int, ?width:Int, ?height:Int):Bool {
		if (bytes == null || bytes.length < 16)
			return false;
		if (bytes.get(0) != 0x13 || bytes.get(1) != 0xab || bytes.get(2) != 0xa1 || bytes.get(3) != 0x5c)
			return false;
		var blockX:Int = bytes.get(4);
		var blockY:Int = bytes.get(5);
		var blocks:Array<String> = ["4x4", "5x4", "5x5", "6x5", "6x6", "8x5", "8x6", "8x8", "10x5", "10x6", "10x8", "10x10", "12x10", "12x12"];
		if (blocks.indexOf(blockX + "x" + blockY) == -1 || bytes.get(6) != 1 || read24(bytes, 13) != 1)
			return false;
		var actualWidth:Int = read24(bytes, 7);
		var actualHeight:Int = read24(bytes, 10);
		if (actualWidth <= 0 || actualHeight <= 0 || actualWidth > 65535 || actualHeight > 65535)
			return false;
		if ((width != null && actualWidth != width) || (height != null && actualHeight != height))
			return false;
		var expected:Float = 16.0 + Math.ceil(actualWidth / blockX) * Math.ceil(actualHeight / blockY) * 16.0;
		return expected == (fileSize == null ? bytes.length : fileSize);
	}

	/** 读取文件头中的小端三字节无符号整数。 */
	private static function read24(bytes:Bytes, offset:Int):Int {
		return bytes.get(offset) | (bytes.get(offset + 1) << 8) | (bytes.get(offset + 2) << 16);
	}
}
