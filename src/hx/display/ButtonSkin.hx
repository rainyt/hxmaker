package hx.display;

import hx.display.BitmapData;

/**
 * 按钮皮肤类型定义
 * 用于指定按钮在不同状态下的外观
 */
typedef ButtonSkin = {
	/**
	 * 按钮正常状态的皮肤
	 * 可选字段，未设置时使用默认外观
	 */
	?up:BitmapData
}
