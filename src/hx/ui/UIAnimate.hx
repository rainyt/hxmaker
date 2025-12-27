package hx.ui;

import motion.Actuate;
import hx.display.DisplayObject;
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

/**
 * UI动画控制程序，通过XML配置实现动画
 */
class UIAnimate {
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

	/**
	 * 缓动函数
	 */
	public var ease:IEasing;

	/**
	 * 动画ID
	 */
	public var id:String;

	private var __isAutoPlay:Bool = false;

	public function new(target:DisplayObject, xml:Xml) {
		this.target = target;
		this.xml = xml;
		this.duration = Std.parseFloat(xml.get("duration"));
		this.delay = xml.exists("delay") ? Std.parseFloat(xml.get("delay")) : 0;
		var easeName:String = xml.get("ease");
		if (easeName != null) {
			var easeNames = easeName.split(".");
			var className:String = easeNames[0];
			className = className.charAt(0).toUpperCase() + className.substr(1);
			var funcName = easeNames[1];
			var easeClass = Type.resolveClass("motion.easing." + className);
			if (easeClass != null) {
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
		if (setStartOption) {
			for (key in this.startOption.fields()) {
				this.target.setProperty(key, this.startOption.getProperty(key));
			}
		}
		var actuate = Actuate.tween(target, duration, endOption, false).onUpdate(() -> {
			if (target.parent != null) {
				target.parent.updateLayout();
			}
		}).delay(delay);
		if (isReverse) {
			actuate.reverse();
		}
		if (ease != null)
			actuate.ease(ease);
	}

	public function updateOption():Void {
		for (item in xml.elements()) {
			var key = item.nodeName;
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
		trace(startOption, endOption);
	}

	/**
	 * 停止播放动画
	 */
	public function stop():Void {
		Actuate.stop(target);
	}
}
