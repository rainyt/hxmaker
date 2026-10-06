package hx.display.button;

import hx.display.Button;

/**
 * 按钮动画行为代理接口
 * 用于控制按钮在鼠标按下/抬起时的动画表现，可由不同的游戏自行实现并传递
 */
interface IAnimateBehavior {
	/**
	 * 鼠标按下时的动画表现
	 * @param button 触发事件的按钮
	 */
	function onMouseDown(button:Button):Void;

	/**
	 * 鼠标抬起时的动画表现
	 * @param button 触发事件的按钮
	 */
	function onMouseUp(button:Button):Void;

	/**
	 * 鼠标点击时的动画表现
	 * @param button 触发事件的按钮
	 */
	function onMouseClick(button:Button):Void;
}
