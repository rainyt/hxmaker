package hx.layout;

import hx.display.DisplayObject;

class Layout implements ILayout {
	public function new() {}

	/**
	 * 父节点
	 */
	public var parent:DisplayObject;

	public function update(children:Array<DisplayObject>) {}
}
