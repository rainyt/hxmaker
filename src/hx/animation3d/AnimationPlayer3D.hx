package hx.animation3d;

import hx.display.EventDispatcher;
import hx.events.AnimationEvent3D;
import hx.render3d.Math3D;

/** 由业务 UPDATE 驱动，绘制回调不修改播放时间。 */
class AnimationPlayer3D extends EventDispatcher {
	/** 是否推进播放；暂停时为 false，仍保留当前姿态与时间。 */
	public var playing(default, null):Bool = false;

	/** 当前目标片段名称；停止或未选择片段时为 null。 */
	public var currentName(get, never):String;

	/** 相对当前目标片段起点的播放时间，单位为秒。 */
	public var time(default, null):Float = 0;

	/** 当前目标片段时长，单位为秒；没有片段时为零。 */
	public var duration(get, never):Float;

	/** 按导入顺序返回可播放片段的名称列表副本。 */
	public var names(get, never):Array<String>;

	/** 非负有限播放倍率，默认 1；零冻结时间与过渡，不支持倒放。 */
	public var speed(get, set):Float;

	/** 是否正在执行姿态过渡。 */
	public var transitioning(default, null):Bool = false;

	/** 过渡完成比例，范围 0 至 1；没有过渡时为 1。 */
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

	private function get_currentName():String {
		return clip == null ? null : clip.name;
	}

	private function get_duration():Float {
		return clip == null ? 0 : clip.duration;
	}

	private function get_names():Array<String> {
		return [for (value in clips) value.name];
	}

	private function get_speed():Float {
		return playbackSpeed;
	}

	private function set_speed(value:Float):Float {
		ensureAlive();
		if (!Math3D.finite(value) || value < 0)
			throw "动画速度必须是非负有限数值";
		execute(() -> {
			playbackSpeed = value;
		});
		return value;
	}

	private function get_transitionProgress():Float {
		return transitioning ? fadeTime / fadeDuration : 1;
	}

	/** 保留原有单片段回调；独立使用播放器时，可选提供姿态混合适配。 */
	public function new(clips:Array<AnimationClip3D>, apply:AnimationClip3D->Float->Void, blending:AnimationBlend3D = null) {
		#if hxmaker_unity
		super();
		#end
		if (clips == null || apply == null)
			throw "动画片段与姿态回调不能为空";
		if (blending != null && (blending.capture == null || blending.apply == null))
			throw "姿态混合适配必须同时提供 capture 与 apply";
		this.clips = clips.copy();
		this.apply = apply;
		this.blending = blending;
	}

	/** 从片段起点重新播放；默认循环，片段不存在时先报错再保持原状态。 */
	public function play(name:String, loop:Bool = true):Void {
		var found = findClip(name);
		execute(() -> start(found, loop));
	}

	/** 同一目标不重播；中断过渡时从当前混合姿态继续。 */
	public function crossFade(name:String, seconds:Float = 0.2, loop:Bool = true):Void {
		var found = findClip(name);
		if (!Math3D.finite(seconds) || seconds < 0)
			throw "动画过渡时间必须是非负有限数值";
		if (seconds > 0 && blending == null)
			throw "动画播放器未提供姿态混合适配";
		execute(() -> {
			if (seconds == 0) {
				start(found, loop);
				return;
			}
			if (clip == found)
				return;
			// null 源片段表示使用适配器保存的姿态快照，不能继续叠加旧过渡。
			if (transitioning || clip == null) {
				blending.capture();
				sourceClip = null;
			} else
				sourceClip = clip;
			sourceTime = sourceClip == null ? 0 : time;
			sourceLoop = this.loop;
			clip = found;
			this.loop = loop;
			time = 0;
			finished = false;
			completionSent = false;
			playing = true;
			fadeTime = 0;
			fadeDuration = seconds;
			transitioning = true;
			applyCurrent();
			emit(AnimationEvent3D.START);
		});
	}

	/** 冻结播放和过渡，保留当前姿态。 */
	public function pause():Void {
		execute(() -> {
			playing = false;
		});
	}

	/** 继续当前片段；没有目标片段时无操作。 */
	public function resume():Void {
		execute(() -> {
			if (clip != null)
				playing = true;
		});
	}

	/** 时间以片段起点为零；取消过渡，但不改变暂停状态。 */
	public function seek(seconds:Float):Void {
		ensureAlive();
		if (!Math3D.finite(seconds))
			throw "动画时间必须是有限数值";
		execute(() -> {
			if (clip == null)
				return;
			cancelFade();
			time = Math.max(0, Math.min(duration, seconds));
			finished = false;
			apply(clip, clip.start + time);
		});
	}

	/** 取消过渡、清空目标并恢复初始姿态。 */
	public function stop():Void {
		execute(() -> {
			cancelFade();
			playing = false;
			clip = null;
			time = 0;
			finished = false;
			apply(null, 0);
		});
	}

	/** 按非负秒数推进一次时间和姿态，姿态应用后派发合并的播放事件。 */
	public function update(dt:Float):Void {
		ensureAlive();
		if (!Math3D.finite(dt) || dt < 0)
			throw "动画时间步长必须是非负有限数值";
		// 常见的无事件、无延迟命令路径不创建命令闭包和队列快照。
		if (deferred.length == 0 && !executing) {
			executing = true;
			try {
				advance(dt);
				flushEvents();
			} catch (error:Dynamic) {
				abortCommands();
				throw error;
			}
			executing = false;
			flushDeferred();
		} else
			execute(() -> advance(dt));
	}

	private function start(found:AnimationClip3D, loop:Bool):Void {
		cancelFade();
		clip = found;
		this.loop = loop;
		time = 0;
		finished = false;
		completionSent = false;
		playing = true;
		apply(clip, clip.start);
		emit(AnimationEvent3D.START);
	}

	private function advance(dt:Float):Void {
		if (!playing || clip == null || dt == 0 || playbackSpeed == 0)
			return;
		var step = dt * playbackSpeed;
		if (!Math3D.finite(step) || !Math3D.finite(time + step) || !Math3D.finite(sourceTime + step))
			throw "动画时间计算超出有限范围";
		if (loop && duration > 0 && !Math3D.finite((time + step) / duration))
			throw "动画循环次数超出有限范围";
		var completed = false, loops = 0.;
		if (!finished) {
			if (duration <= 0) {
				time = 0;
				finished = true;
				completed = true;
			} else if (loop) {
				var total = time + step;
				loops = Math.ffloor(total / duration);
				time = total % duration;
			} else {
				time = Math.min(duration, time + step);
				if (time >= duration) {
					finished = true;
					completed = true;
				}
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
		if (faded)
			cancelFade();
		if (finished && !transitioning)
			playing = false;
		if (loops > 0)
			emit(AnimationEvent3D.LOOP, loops);
		if (completed && !completionSent) {
			completionSent = true;
			emit(AnimationEvent3D.COMPLETE);
		}
		if (faded)
			emit(AnimationEvent3D.FADE_COMPLETE);
	}

	private function applyCurrent():Void {
		if (transitioning && fadeTime < fadeDuration) {
			blending.apply(sourceClip, sourceClip == null ? 0 : sourceClip.start + sourceTime, clip, clip.start + time, transitionProgress);
		} else
			apply(clip, clip == null ? 0 : clip.start + time);
	}

	private function cancelFade():Void {
		transitioning = false;
		sourceClip = null;
		sourceTime = 0;
		fadeTime = fadeDuration = 0;
	}

	private function findClip(name:String):AnimationClip3D {
		ensureAlive();
		for (value in clips)
			if (value.name == name)
				return value;
		throw "找不到三维动画：" + name;
	}

	private function emit(type:String, loopCount:Float = 0):Void {
		if (hasEventListener(type))
			events.push(new AnimationEvent3D(type, currentName, time, loopCount));
	}

	private function flushEvents():Void {
		if (events.length == 0)
			return;
		var batch = events;
		events = [];
		for (event in batch) {
			if (disposed)
				break;
			event.target = this;
			dispatchEvent(event);
		}
	}

	/** 回调中的命令延迟到本批事件结束；再次产生的命令留到下一次播放器操作。 */
	private function execute(command:Void->Void):Void {
		ensureAlive();
		if (executing) {
			deferred.push(command);
			return;
		}
		deferred.push(command);
		runCommands();
		flushDeferred();
	}

	private function flushDeferred():Void {
		if (!disposed && deferred.length > 0)
			runCommands();
	}

	private function runCommands():Void {
		var batch = deferred;
		deferred = [];
		executing = true;
		try {
			for (command in batch) {
				if (disposed)
					break;
				command();
				flushEvents();
			}
		} catch (error:Dynamic) {
			abortCommands();
			throw error;
		}
		executing = false;
	}

	private function abortCommands():Void {
		executing = false;
		events = [];
		deferred = [];
	}

	private function ensureAlive():Void {
		if (disposed)
			throw "三维动画播放器已经销毁";
	}

	/** 幂等清空回调、片段引用、事件和延迟命令，不销毁模型资源。 */
	public function dispose():Void {
		if (disposed)
			return;
		disposed = true;
		playing = false;
		cancelFade();
		clips = [];
		clip = null;
		apply = null;
		blending = null;
		events = [];
		deferred = [];
		removeEventListeners();
	}
}

/** 可选的宿主姿态适配；源片段为 null 时使用 capture 保存的姿态。 */
typedef AnimationBlend3D = {
	/** 保存宿主当前混合姿态，用于中断过渡时继续混合。 */
	var capture:Void->Void;

	/** 按源片段时间、目标片段时间和权重应用姿态；源片段为 null 时使用捕获快照。 */
	var apply:AnimationClip3D->Float->AnimationClip3D->Float->Float->Void;
}
