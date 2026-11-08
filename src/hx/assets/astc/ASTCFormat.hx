package hx.assets.astc;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.zip.InflateImpl;

/** 与渲染后端无关的二维 ASTC 文件识别、外层解压和原始数据校验。 */
class ASTCFormat {
	/** 识别无预设字典的 zlib 数据，不依赖扩展名或特定压缩等级的文件头。 */
	public static function isZlib(bytes:Bytes):Bool {
		if (bytes == null || bytes.length < 6)
			return false;
		var method:Int = bytes.get(0);
		var flags:Int = bytes.get(1);
		return (method & 15) == 8 && (method >> 4) <= 7
			&& ((method << 8) | flags) % 31 == 0 && (flags & 32) == 0;
	}

	/** 自动识别 ASTC；先检查预期大小，可注入平台 zlib 解压器，未提供时使用有界纯 Haxe 实现。 */
	public static function decode(bytes:Bytes, maxBytes:Int = 67108864, ?inflate:Bytes->Bytes):Bytes {
		if (maxBytes < 16)
			throw "ASTC 解压大小上限不能小于文件头";
		if (isValid(bytes)) {
			if (bytes.length > maxBytes)
				throw "ASTC 数据超过大小上限";
			return bytes;
		}
		if (!isZlib(bytes))
			throw "不是有效的 ASTC 或 zlib ASTC 文件";
		var input:BytesInput = new BytesInput(bytes);
		var inflater:InflateImpl = new InflateImpl(input, true, true);
		var header:Bytes = Bytes.alloc(16);
		if (inflater.readBytes(header, 0, 16) != 16)
			throw "ASTC 解压文件头不完整";
		var blockX:Int = header.get(4);
		var blockY:Int = header.get(5);
		if (!isBlockSize(blockX, blockY))
			throw "ASTC 压缩块无效";
		var expected:Float = 16.0 + 16.0 * Math.ceil(read24(header, 7) / blockX) * Math.ceil(read24(header, 10) / blockY);
		if (expected > maxBytes || !isValid(header, Std.int(expected)))
			throw "ASTC 解压尺寸无效或数据超过大小上限";
		var size:Int = Std.int(expected);
		if (inflate != null) {
			var result:Bytes = inflate(bytes);
			if (!isValid(result) || result.length != size)
				throw "ASTC 平台解压结果无效或长度不符";
			return result;
		}
		var decoded:Bytes = Bytes.alloc(size);
		decoded.blit(0, header, 0, 16);
		if (inflater.readBytes(decoded, 16, size - 16) != size - 16)
			throw "ASTC 解压数据不完整";
		// 再读一个字节以结束压缩流并核对 Adler-32，拒绝多余输出和尾随数据。
		var extra:Bytes = Bytes.alloc(1);
		if (inflater.readBytes(extra, 0, 1) != 0 || input.position != input.length)
			throw "ASTC 压缩文件包含多余数据";
		return decoded;
	}

	/** 检查文件头、压缩块、尺寸及完整数据长度，拒绝截断文件和错误页。 */
	public static function isValid(bytes:Bytes, ?fileSize:Int, ?width:Int, ?height:Int):Bool {
		if (bytes == null || bytes.length < 16)
			return false;
		if (bytes.get(0) != 0x13 || bytes.get(1) != 0xab || bytes.get(2) != 0xa1 || bytes.get(3) != 0x5c)
			return false;
		var blockX:Int = bytes.get(4);
		var blockY:Int = bytes.get(5);
		if (!isBlockSize(blockX, blockY) || bytes.get(6) != 1 || read24(bytes, 13) != 1)
			return false;
		var actualWidth:Int = read24(bytes, 7);
		var actualHeight:Int = read24(bytes, 10);
		if (actualWidth <= 0 || actualHeight <= 0 || actualWidth > 65535 || actualHeight > 65535)
			return false;
		if ((width != null && actualWidth != width) || (height != null && actualHeight != height))
			return false;
		var expected:Float = 16.0 + 16.0 * Math.ceil(actualWidth / blockX) * Math.ceil(actualHeight / blockY);
		return expected == (fileSize == null ? bytes.length : fileSize);
	}

	/** ASTC LDR 允许的块尺寸；分支判断避免每次校验分配字符串数组。 */
	private static function isBlockSize(blockX:Int, blockY:Int):Bool {
		return switch (blockX) {
			case 4: blockY == 4;
			case 5: blockY == 4 || blockY == 5;
			case 6: blockY == 5 || blockY == 6;
			case 8: blockY == 5 || blockY == 6 || blockY == 8;
			case 10: blockY == 5 || blockY == 6 || blockY == 8 || blockY == 10;
			case 12: blockY == 10 || blockY == 12;
			default: false;
		}
	}

	/** 读取文件头中的小端三字节无符号整数。 */
	private static function read24(bytes:Bytes, offset:Int):Int {
		return bytes.get(offset) | (bytes.get(offset + 1) << 8) | (bytes.get(offset + 2) << 16);
	}
}
