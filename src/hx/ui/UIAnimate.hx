package hx.ui;

import motion.Actuate;
import hx.display.DisplayObject;
import hx.display.DisplayObjectContainer;
import motion.actuators.GenericActuator;
import motion.easing.Back;
import motion.easing.Bounce;
import motion.easing.Cubic;
import motion.easing.Elastic;
import motion.easing.Expo;
import motion.easing.Linear;
import motion.easing.Quad;
import motion.easing.Quart;
import motion.easing.Quint;
import motion.easing.IEasing;

using Reflect;

private typedef UIAnimateClock = {time:Float};

/**
 * UI动画控制程序，通过XML配置实现动画
 */
class UIAnimate {
	/** XML 通过字符串引用缓动，显式保留函数，避免编译裁剪后无法解析。 */
	private static var easingFunctions:Map<String, IEasing> = [
		"Linear.easeNone" => Linear.easeNone,
		"Back.easeIn" => Back.easeIn, "Back.easeOut" => Back.easeOut, "Back.easeInOut" => Back.easeInOut,
		"Bounce.easeIn" => Bounce.easeIn, "Bounce.easeOut" => Bounce.easeOut, "Bounce.easeInOut" => Bounce.easeInOut,
		"Cubic.easeIn" => Cubic.easeIn, "Cubic.easeOut" => Cubic.easeOut, "Cubic.easeInOut" => Cubic.easeInOut,
		"Elastic.easeIn" => Elastic.easeIn, "Elastic.easeOut" => Elastic.easeOut, "Elastic.easeInOut" => Elastic.easeInOut,
		"Expo.easeIn" => Expo.easeIn, "Expo.easeOut" => Expo.easeOut, "Expo.easeInOut" => Expo.easeInOut,
		"Quad.easeIn" => Quad.easeIn, "Quad.easeOut" => Quad.easeOut, "Quad.easeInOut" => Quad.easeInOut,
		"Quart.easeIn" => Quart.easeIn, "Quart.easeOut" => Quart.easeOut, "Quart.easeInOut" => Quart.easeInOut,
		"Quint.easeIn" => Quint.easeIn, "Quint.easeOut" => Quint.easeOut, "Quint.easeInOut" => Quint.easeInOut
	];

	/**
	 * 动画目标对象开始动画值
	 */
	public var startOption:Dynamic = {};

	/**
	 * 动画目标对象结束动画值
	 */
	public var endOption:Dynamic = {};

	/**
	 * 动画目标对象
	 */
	public var target:DisplayObject;

	/**
	 * 动画XML
	 */
	private var xml:Xml;

	/**
	 * 动画时长
	 */
	public var duration:Float = 0;

	/**
	 * 动画延迟时间
	 */
	public var delay:Float = 0;

	/**
	 * 是否自动播放
	 */
	public var auto:Bool = true;

	/** 启用统一时间轴播放；旧 XML 未声明时保留原有补间行为。 */
	public var timeline:Bool = false;

	/**
	 * 缓动函数
	 */
	public var ease:IEasing;

	/**
	 * 动画ID
	 */
	public var id:String;

	private var __isAutoPlay:Bool = false;
	private var optionsInitialized:Bool = false;
	private var activeTweens:Array<GenericActuator<DisplayObject>> = [];
	private var timelineActuator:GenericActuator<UIAnimateClock>;

	/** 包含延迟的总时长，单位为秒。 */
	public var totalDuration(get, never):Float;

	private function get_totalDuration():Float {
		validateSeekTiming();
		return delay + duration;
	}

	public function new(target:DisplayObject, xml:Xml) {
		this.target = target;
		this.xml = xml;
		this.timeline = xml.get("timeline") == "true";
		this.duration = xml.exists("duration") ? Std.parseFloat(xml.get("duration")) : 0;
		this.delay = xml.exists("delay") ? Std.parseFloat(xml.get("delay")) : 0;
		var easeName:String = xml.get("ease");
		if (easeName != null) {
			var easeNames:Array<String> = easeName.split(".");
			var className:String = easeNames[0];
			className = className.charAt(0).toUpperCase() + className.substr(1);
			var funcName:String = easeNames[1];
			this.ease = easingFunctions.get(className + "." + funcName);
			if (this.ease == null) {
				var easeClass:Class<Dynamic> = Type.resolveClass("motion.easing." + className);
				if (easeClass != null)
					this.ease = Reflect.getProperty(easeClass, funcName);
			}
		}
	}

	/**
	 * 开始播放动画
	 * @param setStartOption 是否设置开始动画值
	 * @param isReverse 是否反向播放
	 */
	public function play(setStartOption:Bool = false, isReverse:Bool = false):Void {
		if (timeline) {
			playTimeline(isReverse);
			return;
		}
		if (!optionsInitialized)
			updateOption();
		if (setStartOption) {
			for (key in this.startOption.fields()) {
				this.target.setProperty(key, this.startOption.getProperty(key));
			}
		}
		var actuate:GenericActuator<DisplayObject> = Actuate.tween(target, duration, endOption, false).onUpdate(() -> {
			if (target.parent != null) {
				target.parent.updateLayout();
			}
		}).delay(delay);
		if (isReverse) {
			actuate.reverse();
		}
		if (ease != null)
			actuate.ease(ease);
		activeTweens.push(actuate);
		actuate.onComplete(() -> activeTweens.remove(actuate));
	}

	public function updateOption():Void {
		for (item in xml.elements()) {
			var key:String = item.nodeName;
			if (item.exists("start")) {
				startOption.setProperty(key, Std.parseFloat(item.get("start")));
			} else {
				startOption.setProperty(key, target.getProperty(key));
			}
			if (item.exists("end")) {
				endOption.setProperty(key, Std.parseFloat(item.get("end")));
			} else {
				endOption.setProperty(key, target.getProperty(key));
			}
		}
		optionsInitialized = true;
	}

	/**
	 * 定位到指定时间并保持静止，不触发播放或完成回调。
	 * 时间单位为秒，包含 delay；负数按零处理，超过末尾保持结束值。
	 * 首次定位前捕获缺省起止值，后续定位复用；需要重新捕获时显式调用 updateOption()。
	 * 动画组按属性选择最后开始的片段，同起点时以组内靠后的片段为准。
	 */
	public function seek(time:Float):Void {
		if (!Math.isFinite(time))
			throw "动画定位时间必须为有限数值";
		stopSeekPlayback();
		applyTime(time);
	}

	/**
	 * 使用与 seek 相同的规则播放完整时间轴，每次从首帧或反向末帧重新开始。
	 * 所有片段共用一个时钟，延迟、空白区间、零时长和同属性覆盖均由时间求值决定。
	 */
	public function playTimeline(isReverse:Bool = false):Void {
		stopSeekPlayback();
		var total:Float = totalDuration;
		var clock:UIAnimateClock = {time: isReverse ? total : 0};
		applyTime(clock.time);
		if (total == 0) return;
		timelineActuator = Actuate.tween(clock, total, {time: isReverse ? 0.0 : total}, false)
			.ease(Linear.easeNone)
			.onUpdate(() -> applyTime(clock.time))
			.onComplete(() -> timelineActuator = null);
	}

	/** 播放时不能调用 seek，否则会把驱动时间轴的自身时钟停掉。 */
	private function applyTime(time:Float):Void {
		time = Math.max(0, time);
		var tracks:Array<UIAnimate> = [];
		collectSeekTracks(tracks);
		// 所有片段先读取静态基准，避免前一个片段写入后污染后一个片段的缺省值。
		for (track in tracks) {
			track.validateSeekTiming();
			if (track.target == null)
				throw "动画定位目标不能为空";
			if (!track.optionsInitialized)
				track.updateOption();
			track.validateSeekOptions();
		}
		var owners:Map<DisplayObject, Map<String, UIAnimate>> = [];
		for (track in tracks) {
			var properties:Map<String, UIAnimate> = owners.get(track.target);
			if (properties == null) {
				properties = [];
				owners.set(track.target, properties);
			}
			for (key in track.startOption.fields()) {
				var previous:UIAnimate = properties.get(key);
				// 已开始的片段覆盖未来片段；尚未开始时选最早片段的起始值。
				var owns:Bool = previous == null;
				if (previous != null) {
					owns = track.delay <= time
						? previous.delay > time || track.delay >= previous.delay
						: previous.delay > time && track.delay <= previous.delay;
				}
				if (owns)
					properties.set(key, track);
			}
		}
		var parents:Map<DisplayObjectContainer, Bool> = [];
		for (track in tracks) {
			var progress:Float = time < track.delay ? 0 : track.duration == 0 ? 1 : Math.min(1, (time - track.delay) / track.duration);
			var easing:IEasing = track.ease == null ? Actuate.defaultEase : track.ease;
			var ratio:Float = easing.calculate(progress);
			var properties:Map<String, UIAnimate> = owners.get(track.target);
			var changed:Bool = false;
			for (key in track.startOption.fields()) {
				if (properties.get(key) != track)
					continue;
				var start:Float = track.startOption.getProperty(key);
				var end:Float = track.endOption.getProperty(key);
				track.target.setProperty(key, start + (end - start) * ratio);
				changed = true;
			}
			if (changed && track.target.parent != null)
				parents.set(track.target.parent, true);
		}
		// 同一父级仅重排一次，沿用正常播放时的布局规则。
		for (parent in parents.keys())
			parent.updateLayout();
	}

	@:allow(hx.ui.UIAnimateGroup)
	private function collectSeekTracks(tracks:Array<UIAnimate>):Void {
		tracks.push(this);
	}

	private function validateSeekTiming():Void {
		if (!Math.isFinite(duration) || duration < 0 || !Math.isFinite(delay) || delay < 0 || !Math.isFinite(delay + duration))
			throw "动画时长和延迟必须为非负有限数值";
	}

	private function validateSeekOptions():Void {
		if (target == null)
			throw "动画定位目标不能为空";
		for (key in startOption.fields()) {
			var start:Dynamic = startOption.getProperty(key);
			var end:Dynamic = endOption.getProperty(key);
			if (!Std.isOfType(start, Float) || !Std.isOfType(end, Float) || !Math.isFinite(start) || !Math.isFinite(end))
				throw "动画属性必须具有有效的数值起止值：" + key;
		}
	}

	/** 只停止当前动画创建的补间，保留同一目标上的其他动画。 */
	@:allow(hx.ui.UIAnimateGroup)
	private function stopSeekPlayback():Void {
		if (timelineActuator != null) {
			Actuate.stop(timelineActuator, null, false, false);
			timelineActuator = null;
		}
		for (actuate in activeTweens)
			Actuate.stop(actuate, null, false, false);
		activeTweens = [];
	}

	/**
	 * 停止播放动画
	 */
	public function stop():Void {
		stopSeekPlayback();
		Actuate.stop(target);
		activeTweens = [];
	}
}
