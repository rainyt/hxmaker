package hx.animation3d;

import hx.display.EventDispatcher;
import hx.events.AnimationEvent3D;
import hx.render3d.Math3D;

/** 由业务 UPDATE 驱动，绘制回调不修改播放时间。 */
class AnimationPlayer3D extends EventDispatcher {
	public var playing(default, null):Bool = false;
	public var currentName(get, never):String;
	public var time(default, null):Float = 0;
	public var duration(get, never):Float;
	public var names(get, never):Array<String>;
	public var speed(get, set):Float;
	public var transitioning(default, null):Bool = false;
	public var transitionProgress(get, never):Float;
	private var playbackSpeed:Float = 1;
	private var clips:Array<AnimationClip3D>;
	private var clip:AnimationClip3D;
	private var loop:Bool = true;
	private var finished:Bool = false;
	private var completionSent:Bool = false;
	private var sourceClip:AnimationClip3D;
	private var sourceTime:Float = 0;
	private var sourceLoop:Bool = true;
	private var fadeTime:Float = 0;
	private var fadeDuration:Float = 0;
	private var apply:AnimationClip3D->Float->Void;
	private var blending:AnimationBlend3D;
	private var disposed:Bool = false;
	private var executing:Bool = false;
	private var deferred:Array<Void->Void> = [];
	private var events:Array<AnimationEvent3D> = [];
	private function get_currentName():String { return clip == null ? null : clip.name; }
	private function get_duration():Float { return clip == null ? 0 : clip.duration; }
	private function get_names():Array<String> { return [for (value in clips) value.name]; }
	private function get_speed():Float { return playbackSpeed; }
	private function set_speed(value:Float):Float {
		ensureAlive();
		if (!Math3D.finite(value) || value < 0) throw "动画速度必须是非负有限数值";
		execute(() -> { playbackSpeed = value; }); return value;
	}
	private function get_transitionProgress():Float { return transitioning ? fadeTime / fadeDuration : 1; }
	/** 保留原有单片段回调；独立使用播放器时，可选提供姿态混合适配。 */
	public function new(clips:Array<AnimationClip3D>, apply:AnimationClip3D->Float->Void, blending:AnimationBlend3D = null) {
		if (clips == null || apply == null) throw "动画片段与姿态回调不能为空";
		if (blending != null && (blending.capture == null || blending.apply == null)) throw "姿态混合适配必须同时提供 capture 与 apply";
		this.clips = clips.copy(); this.apply = apply; this.blending = blending;
	}
	public function play(name:String, loop:Bool = true):Void {
		var found = findClip(name);
		execute(() -> start(found, loop));
	}
	/** 同一目标不重播；中断过渡时从当前混合姿态继续。 */
	public function crossFade(name:String, seconds:Float = 0.2, loop:Bool = true):Void {
		var found = findClip(name);
		if (!Math3D.finite(seconds) || seconds < 0) throw "动画过渡时间必须是非负有限数值";
		if (seconds > 0 && blending == null) throw "动画播放器未提供姿态混合适配";
		execute(() -> {
			if (seconds == 0) { start(found, loop); return; }
			if (clip == found) return;
			// null 源片段表示使用适配器保存的姿态快照，不能继续叠加旧过渡。
			if (transitioning || clip == null) { blending.capture(); sourceClip = null; }
			else sourceClip = clip;
			sourceTime = sourceClip == null ? 0 : time; sourceLoop = this.loop;
			clip = found; this.loop = loop; time = 0; finished = false; completionSent = false; playing = true;
			fadeTime = 0; fadeDuration = seconds; transitioning = true;
			applyCurrent(); emit(AnimationEvent3D.START);
		});
	}
	public function pause():Void { execute(() -> { playing = false; }); }
	public function resume():Void { execute(() -> { if (clip != null) playing = true; }); }
	/** 时间以片段起点为零；取消过渡，但不改变暂停状态。 */
	public function seek(seconds:Float):Void {
		ensureAlive();
		if (!Math3D.finite(seconds)) throw "动画时间必须是有限数值";
		execute(() -> {
			if (clip == null) return;
			cancelFade(); time = Math.max(0, Math.min(duration, seconds)); finished = false;
			apply(clip, clip.start + time);
		});
	}
	public function stop():Void {
		execute(() -> {
			cancelFade(); playing = false; clip = null; time = 0; finished = false; apply(null, 0);
		});
	}
	public function update(dt:Float):Void {
		ensureAlive();
		if (!Math3D.finite(dt) || dt < 0) throw "动画时间步长必须是非负有限数值";
		// 常见的无事件、无延迟命令路径不创建命令闭包和队列快照。
		if (deferred.length == 0 && !executing) {
			executing = true;
			try { advance(dt); flushEvents(); } catch (error:Dynamic) { abortCommands(); throw error; }
			executing = false; flushDeferred();
		} else execute(() -> advance(dt));
	}
	private function start(found:AnimationClip3D, loop:Bool):Void {
		cancelFade(); clip = found; this.loop = loop; time = 0; finished = false; completionSent = false; playing = true;
		apply(clip, clip.start); emit(AnimationEvent3D.START);
	}
	private function advance(dt:Float):Void {
		if (!playing || clip == null || dt == 0 || playbackSpeed == 0) return;
		var step = dt * playbackSpeed;
		if (!Math3D.finite(step) || !Math3D.finite(time + step) || !Math3D.finite(sourceTime + step))
			throw "动画时间计算超出有限范围";
		if (loop && duration > 0 && !Math3D.finite((time + step) / duration)) throw "动画循环次数超出有限范围";
		var completed = false, loops = 0.;
		if (!finished) {
			if (duration <= 0) { time = 0; finished = true; completed = true; }
			else if (loop) {
				var total = time + step; loops = Math.ffloor(total / duration); time = total % duration;
			} else {
				time = Math.min(duration, time + step);
				if (time >= duration) { finished = true; completed = true; }
			}
		}
		var faded = false;
		if (transitioning) {
			if (sourceClip != null && sourceClip.duration > 0) {
				var total = sourceTime + step;
				sourceTime = sourceLoop ? total % sourceClip.duration : Math.min(sourceClip.duration, total);
			}
			fadeTime = Math.min(fadeDuration, fadeTime + step);
			faded = fadeTime >= fadeDuration;
		}
		applyCurrent();
		if (faded) cancelFade();
		if (finished && !transitioning) playing = false;
		if (loops > 0) emit(AnimationEvent3D.LOOP, loops);
		if (completed && !completionSent) { completionSent = true; emit(AnimationEvent3D.COMPLETE); }
		if (faded) emit(AnimationEvent3D.FADE_COMPLETE);
	}
	private function applyCurrent():Void {
		if (transitioning && fadeTime < fadeDuration) {
			blending.apply(sourceClip, sourceClip == null ? 0 : sourceClip.start + sourceTime,
				clip, clip.start + time, transitionProgress);
		} else apply(clip, clip == null ? 0 : clip.start + time);
	}
	private function cancelFade():Void {
		transitioning = false; sourceClip = null; sourceTime = 0; fadeTime = fadeDuration = 0;
	}
	private function findClip(name:String):AnimationClip3D {
		ensureAlive();
		for (value in clips) if (value.name == name) return value;
		throw "找不到三维动画：" + name;
	}
	private function emit(type:String, loopCount:Float = 0):Void {
		if (hasEventListener(type)) events.push(new AnimationEvent3D(type, currentName, time, loopCount));
	}
	private function flushEvents():Void {
		if (events.length == 0) return;
		var batch = events; events = [];
		for (event in batch) {
			if (disposed) break;
			event.target = this; dispatchEvent(event);
		}
	}
	/** 回调中的命令延迟到本批事件结束；再次产生的命令留到下一次播放器操作。 */
	private function execute(command:Void->Void):Void {
		ensureAlive();
		if (executing) { deferred.push(command); return; }
		deferred.push(command); runCommands(); flushDeferred();
	}
	private function flushDeferred():Void { if (!disposed && deferred.length > 0) runCommands(); }
	private function runCommands():Void {
		var batch = deferred; deferred = []; executing = true;
		try {
			for (command in batch) {
				if (disposed) break;
				command(); flushEvents();
			}
		} catch (error:Dynamic) { abortCommands(); throw error; }
		executing = false;
	}
	private function abortCommands():Void { executing = false; events = []; deferred = []; }
	private function ensureAlive():Void { if (disposed) throw "三维动画播放器已经销毁"; }
	public function dispose():Void {
		if (disposed) return;
		disposed = true; playing = false; cancelFade(); clips = []; clip = null;
		apply = null; blending = null; events = []; deferred = []; removeEventListeners();
	}
}

/** 可选的宿主姿态适配；源片段为 null 时使用 capture 保存的姿态。 */
typedef AnimationBlend3D = {
	var capture:Void->Void;
	var apply:AnimationClip3D->Float->AnimationClip3D->Float->Float->Void;
}
