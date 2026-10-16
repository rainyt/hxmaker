package hx.animation3d;

/** 只读关键帧数据，播放状态由每个模型实例独立持有。 */
class AnimationClip3D {
	public var name(default, null):String;
	public var start(default, null):Float;
	public var end(default, null):Float;
	public var duration(get, never):Float;
	public var tracks(default, null):Array<AnimationTrack3D>;
	private function get_duration():Float { return end - start; }
	public function new(name:String, tracks:Array<AnimationTrack3D>) {
		this.name = name; this.tracks = tracks;
		start = Math.POSITIVE_INFINITY; end = Math.NEGATIVE_INFINITY;
		for (track in tracks) {
			start = Math.min(start, track.times[0]); end = Math.max(end, track.times[track.times.length - 1]);
		}
		if (tracks.length == 0) start = end = 0;
	}
	/** 输出复用目标数组，旋转插值归一化并选择四元数最短路径。 */
	public static function sample(track:AnimationTrack3D, time:Float, out:Array<Float>):Void {
		var times = track.times, width = track.path == "rotation" ? 4 : 3;
		var low = 0, high = times.length - 1;
		while (low < high) {
			var middle = Std.int((low + high + 1) / 2);
			if (times[middle] <= time) low = middle; else high = middle - 1;
		}
		var next = Std.int(Math.min(low + 1, times.length - 1));
		var t = time <= times[0] || next == low || track.interpolation == "STEP" ? 0. : (time - times[low]) / (times[next] - times[low]);
		t = Math.max(0, Math.min(1, t));
		var a = low * width, b = next * width, values = track.values;
		if (width == 4) blendRotation(values, a, values, b, t, out);
		else for (i in 0...width) out[i] = values[a + i] * (1 - t) + values[b + i] * t;
	}
	/** 关键帧和跨片段混合使用相同的四元数最短路径插值。 */
	public static function blendRotation(a:Array<Float>, offsetA:Int, b:Array<Float>, offsetB:Int, t:Float, out:Array<Float>):Void {
		var dot = 0.; for (i in 0...4) dot += a[offsetA + i] * b[offsetB + i];
		var sign = dot < 0 ? -1. : 1.; dot = Math.min(1, Math.abs(dot));
		var wa = 1 - t, wb = t;
		if (dot < 0.9995) {
			var angle = Math.acos(dot), sine = Math.sin(angle);
			wa = Math.sin((1 - t) * angle) / sine; wb = Math.sin(t * angle) / sine;
		}
		var length = 0.;
		for (i in 0...4) { out[i] = a[offsetA + i] * wa + b[offsetB + i] * wb * sign; length += out[i] * out[i]; }
		length = Math.sqrt(length);
		if (length > 1e-12) for (i in 0...4) out[i] /= length;
		else { out[0] = out[1] = out[2] = 0; out[3] = 1; }
	}
}

typedef AnimationTrack3D = {
	var node:Int;
	var path:String;
	var interpolation:String;
	var times:Array<Float>;
	var values:Array<Float>;
}
