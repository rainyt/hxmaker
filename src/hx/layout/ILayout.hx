package hx.layout;

import hx.display.DisplayObject;

interface ILayout {
	/**
	 * 布局更新
	 * @param children 
	 */
	public function update(children:Array<DisplayObject>):Void;
}
