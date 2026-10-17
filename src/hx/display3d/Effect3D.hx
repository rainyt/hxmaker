package hx.display3d;

import hx.events.Event;
import hx.render3d.Math3D;

/** 组合特效播放器；拥有粒子与拖尾轨道节点，不接管共享材质和贴图。 */
class Effect3D extends Node3D {
	public var playing(default, null):Bool = false;
	public var paused:Bool = false;
	public var speed:Float = 1;
	/** 全部轨道自然收尾后从头循环；停止后不再循环。 */
	public var loop:Bool = false;
	private var tracks:Array<EffectTrack3D> = [];
	private var time:Float = 0;
	private var stopping:Bool = false;

	public function new() { super(); }

	/** 仅在停止时编辑轨道；粒子轨道使用自身配置的发射持续时间。 */
	public function addEmitter(emitter:ParticleSystem3D, delay:Float = 0):ParticleSystem3D {
		validateTrack(emitter, delay);
		if (emitter.playing) throw "请先停止粒子发射器再加入轨道";
		addChild(emitter); tracks.push(new EffectTrack3D(emitter, null, delay, 0)); return emitter;
	}

	/** 刀光或弹道轨道，duration 为采样秒数；之后等待历史轨迹自然收尾。 */
	public function addRibbon(ribbon:Ribbon3D, delay:Float = 0, duration:Float = 0.5):Ribbon3D {
		validateTrack(ribbon, delay);
		if (ribbon.playing || !Math3D.finite(duration) || duration <= 0 || !Math3D.finite(delay + duration)) throw "拖尾轨道必须停止且采样时间必须为正有限值";
		addChild(ribbon); tracks.push(new EffectTrack3D(null, ribbon, delay, duration)); return ribbon;
	}

	private function validateTrack(node:Node3D, delay:Float):Void {
		if (isDisposed || playing || node == null || node.isDisposed || !Math3D.finite(delay) || delay < 0)
			throw "特效轨道或延迟无效，请在停止状态编辑";
		for (track in tracks) if (track.node() == node) throw "不能重复加入同一个特效轨道";
	}

	public function play():Void {
		if (isDisposed) throw "特效已经销毁";
		time = 0; stopping = false; paused = false; playing = true;
		for (track in tracks) { track.stop(true); track.started = track.stopped = false; }
	}

	/** 默认取消尚未开始的轨道，并等待存活粒子和轨迹收尾。 */
	public function stop(clearParticles:Bool = false):Void {
		if (isDisposed || !playing) return;
		stopping = true;
		for (track in tracks) { track.stop(clearParticles); track.stopped = true; }
		if (clearParticles) complete();
	}

	public function update(dt:Float, camera:Camera3D):Void {
		if (isDisposed || !Math3D.finite(dt) || dt < 0 || !Math3D.finite(speed) || speed < 0
			|| !Math3D.finite(dt * speed) || !Math3D.finite(time + dt * speed)) throw "特效时间和速度必须是非负有限数值";
		if (!playing) return;
		var frozen = paused || speed == 0;
		var step = frozen ? 0 : dt * speed, previous = time;
		time += step;
		var pending = false;
		for (track in tracks) {
			var node = track.node();
			if (node.isDisposed || node.parent != this) throw "特效轨道已销毁或离开播放器";
			var from = previous;
			if (!track.started && !stopping && !frozen && time >= track.delay) {
				track.started = true; track.start(); from = Math.max(previous, track.delay);
			}
			if (track.started) {
				var cutoff = track.delay + track.duration;
				if (track.ribbon != null && !track.stopped && time >= cutoff && !frozen) {
					track.advance(Math.max(0, cutoff - from), camera, frozen);
					track.stop(false); track.stopped = true;
					track.advance(Math.max(0, time - Math.max(from, cutoff)), camera, frozen);
				} else track.advance(Math.max(0, time - from), camera, frozen);
			}
			if ((!track.started && !stopping) || track.isPlaying()) pending = true;
		}
		if (!pending) {
			if (loop && !stopping && tracks.length > 0) play(); else complete();
		}
	}

	private function complete():Void {
		if (!playing) return;
		playing = false; dispatchEvent(new Event(Event.COMPLETE));
	}

	override public function dispose():Void {
		if (isDisposed) return;
		playing = false; tracks = []; super.dispose();
	}
}

/** 同一时间轴内统一推进粒子与拖尾，不改变各节点的独立使用接口。 */
private class EffectTrack3D {
	public var emitter:ParticleSystem3D;
	public var ribbon:Ribbon3D;
	public var delay:Float;
	public var duration:Float;
	public var started:Bool = false;
	public var stopped:Bool = false;
	public function new(emitter:ParticleSystem3D, ribbon:Ribbon3D, delay:Float, duration:Float) {
		this.emitter = emitter; this.ribbon = ribbon; this.delay = delay; this.duration = duration;
	}
	public function node():Node3D { return emitter != null ? emitter : ribbon; }
	public function isPlaying():Bool { return emitter != null ? emitter.playing : ribbon.playing; }
	public function start():Void { if (emitter != null) emitter.play(); else ribbon.play(); }
	public function stop(clear:Bool):Void { if (emitter != null) emitter.stop(clear); else ribbon.stop(clear); }
	public function advance(dt:Float, camera:Camera3D, paused:Bool):Void {
		if (emitter != null) { emitter.update(dt, camera); return; }
		var previous = ribbon.paused;
		ribbon.paused = previous || paused;
		try { ribbon.update(dt, camera); } catch (error:Dynamic) { ribbon.paused = previous; throw error; }
		ribbon.paused = previous;
	}
}
