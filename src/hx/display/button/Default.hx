package hx.display.button;

import hx.display.Button;

/**
 * 默认的按钮动画行为
 * 按下时按钮整体缩小至0.94倍，抬起时恢复原始大小
 */
class Default implements IAnimateBehavior {
	public function new() {}

	/**
	 * 鼠标按下时的动画表现，将按钮缩小至0.94倍
	 * @param button 触发事件的按钮
	 */
	public function onMouseDown(button:Button):Void {
		var pWidth = button.width;
		var pHeight = button.height;
		button.box.scale = 0.94;
		button.box.originX = pWidth * 0.03;
		button.box.originY = pHeight * 0.03;
	}

	/**
	 * 鼠标抬起时的动画表现，将按钮恢复原始大小
	 * @param button 触发事件的按钮
	 */
	public function onMouseUp(button:Button):Void {
		button.box.scaleX = 1;
		button.box.scaleY = 1;
		button.box.originX = 0;
		button.box.originY = 0;
	}

	/**
	 * 鼠标点击时的动画表现，默认无动画
	 * @param button 触发事件的按钮
	 */
	public function onMouseClick(button:Button):Void {}
}
