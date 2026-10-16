package hx.animation3d;

import hx.render3d.Math3D;

/** 由业务 UPDATE 驱动，绘制回调不修改播放时间。 */
class AnimationPlayer3D {
	public var playing(default, null):Bool = false;
	public var currentName(get, never):String;
	public var time(default, null):Float = 0;
	public var duration(get, never):Float;
	public var names(get, never):Array<String>;
	private var clips:Array<AnimationClip3D>;
	private var clip:AnimationClip3D;
	private var loop:Bool = true;
	private var apply:AnimationClip3D->Float->Void;
	private var disposed:Bool = false;
	private function get_currentName():String { return clip == null ? null : clip.name; }
	private function get_duration():Float { return clip == null ? 0 : clip.duration; }
	private function get_names():Array<String> { return [for (value in clips) value.name]; }
	public function new(clips:Array<AnimationClip3D>, apply:AnimationClip3D->Float->Void) { this.clips = clips; this.apply = apply; }
	public function play(name:String, loop:Bool = true):Void {
		ensureAlive();
		var found:AnimationClip3D = null;
		for (value in clips) if (value.name == name) { found = value; break; }
		if (found == null) throw "找不到三维动画：" + name;
		clip = found; this.loop = loop; time = 0; playing = true; apply(clip, clip.start);
	}
	public function pause():Void { playing = false; }
	public function resume():Void { ensureAlive(); if (clip != null) playing = true; }
	/** 时间以片段起点为零，seek 不改变暂停状态。 */
	public function seek(seconds:Float):Void {
		ensureAlive();
		if (!Math3D.finite(seconds)) throw "动画时间必须是有限数值";
		if (clip == null) return;
		time = Math.max(0, Math.min(duration, seconds)); apply(clip, clip.start + time);
	}
	public function stop():Void {
		ensureAlive(); playing = false; clip = null; time = 0; apply(null, 0);
	}
	public function update(dt:Float):Void {
		ensureAlive();
		if (!Math3D.finite(dt) || dt < 0) throw "动画时间步长必须是非负有限数值";
		if (!playing || clip == null || dt == 0) return;
		time += dt;
		if (duration <= 0) { time = 0; playing = false; }
		else if (loop) time %= duration;
		else if (time >= duration) { time = duration; playing = false; }
		apply(clip, clip.start + time);
	}
	private function ensureAlive():Void { if (disposed) throw "三维动画播放器已经销毁"; }
	public function dispose():Void { disposed = true; playing = false; clips = []; clip = null; apply = null; }
}
