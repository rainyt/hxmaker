package hx.ui;

import motion.Actuate;
import hx.display.DisplayObject;

using Reflect;

/**
 * UI动画控制程序，通过XML配置实现动画
 */
class UIAniamte {
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

	private var xml:Xml;

	/**
	 * 动画时长
	 */
	public var duration:Float = 0;

	public function new(target:DisplayObject, xml:Xml) {
		this.target = target;
		this.xml = xml;
		this.duration = Std.parseFloat(xml.get("duration"));
	}

	/**
	 * 开始播放动画
	 */
	public function start():Void {
		for (key in startOption.fields()) {
			target.setProperty(key, startOption.getProperty(key));
		}
		Actuate.tween(target, duration, endOption, false).onComplete(() -> {
			trace("动画结束");
		}).onUpdate(() -> {
			if (target.parent != null) {
				target.parent.updateLayout();
			}
		});
		trace(startOption, endOption);
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
}
