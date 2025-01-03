package hx.assets;

import haxe.zip.Reader;
import haxe.io.Path;
import haxe.zip.Entry;
import haxe.io.BytesInput;
import haxe.io.Bytes;
#if lime
import lime._internal.format.Deflate;
#end

/**
 * zip压缩数据读取支持
 */
class Zip {
	/**
	 * zip包读取器
	 */
	private var reader:Reader;

	/**
	 * 压缩文件
	 */
	public var entrys:Map<String, Entry>;

	public function new(bytes:Bytes) {
		var input:BytesInput = new BytesInput(bytes);
		reader = new Reader(input);
		entrys = new Map();
	}

	/**
	 * 读取解压后的二进制
	 * @param entry 
	 * @return Bytes
	 */
	public function readBytes(id:String):Bytes {
		var entry:Entry = entrys.get(id);
		var bytes:Bytes = decompress(entry);
		return bytes;
	}

	/**
	 * 开始解析压缩包
	 * @param call 
	 */
	public function unzip():Void {
		var list = reader.read();
		for (entry in list) {
			if (entry != null) {
				var id:String = Assets.formatName(entry.fileName);
				var ext:String = Path.extension(entry.fileName);
				entrys.set(id + "." + ext, entry);
			} else {
				return;
			}
		}
	}

	/**
	 * Zip统一解压实现
	 * @param entry 
	 * @return Bytes
	 */
	public function decompress(entry:Entry):Bytes {
		#if lime
		entry.data = entry.compressed ? Deflate.decompress(entry.data) : entry.data;
		entry.compressed = false;
		return entry.data;
		#elseif deflatex
		if (entry.compressed) {
			var inflater:deflatex.Inflater = new deflatex.Inflater();
			entry.data = inflater.decompress(entry.data);
		}
		entry.compressed = false;
		return entry.data;
		#else
		if (entry.compressed) {
			var newBytes = Reader.unzip(entry);
			entry.data = newBytes;
			entry.compressed = false;
		}
		return entry.data;
		#end
	}
}
