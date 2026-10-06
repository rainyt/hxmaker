package hx.display.button;

import motion.Actuate;
import motion.easing.Quad;
import hx.display.Button;

/**
 * 按下弹跳的按钮动画行为
 * 仅在点击时表现动画：瞬间缩小，随后自动放大恢复至原始大小，按下与抬起无动画表现
 */
class PressBounce implements IAnimateBehavior {
	/**
	 * 点击瞬间缩小的比例
	 */
	public var pressScale:Float;

	/**
	 * 放大恢复的动画时长，单位为秒
	 */
	public var duration:Float;

	/**
	 * 构造一个按下弹跳动画行为
	 * @param pressScale 点击瞬间缩小的比例，默认为0.9
	 * @param duration 放大恢复的动画时长，单位为秒，默认为0.15
	 */
	public function new(pressScale:Float = 0.9, duration:Float = 0.15) {
		this.pressScale = pressScale;
		this.duration = duration;
	}

	/**
	 * 鼠标按下时无动画表现
	 * @param button 触发事件的按钮
	 */
	public function onMouseDown(button:Button):Void {}

	/**
	 * 鼠标抬起时无动画表现
	 * @param button 触发事件的按钮
	 */
	public function onMouseUp(button:Button):Void {}

	/**
	 * 鼠标点击时的动画表现，瞬间缩小后以中心为基准放大恢复
	 * @param button 触发事件的按钮
	 */
	public function onMouseClick(button:Button):Void {
		Actuate.stop(button.box);
		var pWidth = button.width;
		var pHeight = button.height;
		// 原点偏移与缩放比例满足`origin = size * (1 - scale) / 2`，保证缩放始终以按钮中心为基准
		button.box.scale = pressScale;
		button.box.originX = pWidth * (1 - pressScale) / 2;
		button.box.originY = pHeight * (1 - pressScale) / 2;
		Actuate.tween(button.box, duration, {scaleX: 1, scaleY: 1, originX: 0, originY: 0}).ease(Quad.easeOut);
	}
}
