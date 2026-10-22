package hx.effect3d;

import hx.render3d.Math3D;

/** 等尺寸图集，从左到右、从上到下；UV 相对于材质贴图区域。 */
class SpriteSheet3D {
	public var columns(default, null):Int;
	public var rows(default, null):Int;
	public var frameCount(default, null):Int;

	public function new(columns:Int = 1, rows:Int = 1, frameCount:Int = 0) {
		if (columns <= 0 || rows <= 0 || frameCount < 0 || columns * 1.0 * rows > 65536 || frameCount > columns * rows)
			throw "序列帧图集尺寸或帧数无效";
		this.columns = columns;
		this.rows = rows;
		this.frameCount = frameCount == 0 ? columns * rows : frameCount;
	}

	/** 返回左、上、右、下 UV；帧索引自动限制到有效范围。 */
	public function frameUV(frame:Int):Array<Float> {
		frame = Std.int(Math.max(0, Math.min(frameCount - 1, frame)));
		var x = frame % columns, y = Std.int(frame / columns);
		return [x / columns, y / rows, (x + 1) / columns, (y + 1) / rows];
	}

	/** 按归一化寿命播放一次，末端停留最后一帧。 */
	public function lifeFrame(t:Float):Int {
		if (!Math3D.finite(t))
			throw "序列帧时间必须有限";
		return Std.int(Math.max(0, Math.min(frameCount - 1, Math.floor(t * frameCount))));
	}
}
