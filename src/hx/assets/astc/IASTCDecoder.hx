package hx.assets.astc;

import haxe.io.Bytes;
import hx.display.BitmapData;

/**
 * 渲染后端的 ASTC 能力接口，核心运行时只依赖这个接口，不直接引用平台类型。
 */
interface IASTCDecoder {
	/** 当前设备与渲染上下文是否支持 ASTC 纹理上传。 */
	public function isSupported():Bool;

	/** 把校验过的 ASTC 字节上传为 GPU 压缩纹理。 */
	public function fromBytes(bytes:Bytes):BitmapData;

	/** ASTC 外层 zlib 解压；平台没有优化实现时返回纯 Haxe 解压结果即可。 */
	public function inflate(bytes:Bytes):Bytes;
}
