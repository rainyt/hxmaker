package hx.display;

import hx.geom.Rectangle;
import hx.providers.IRootDataProvider;

/**
 * 自定义显示对象
 */
class CustomDisplayObject extends DisplayObject implements IRootDataProvider<Dynamic> {
	/**
	 * 自定义渲染对象
	 */
	public var root(get, set):Dynamic;

	@:noCompletion private function get_root():Dynamic {
		return __root;
	}

	@:noCompletion private function set_root(value:Dynamic):Dynamic {
		this.__root = value;
		return __root;
	}

	/**
	 * 创建一个新的自定义显示对象
	 * @param display 自定义渲染对象
	 */
	public function new(display:Dynamic) {
		super();
		@:privateAccess this.root = display;
	}

	override function __getRect():Rectangle {
		if (root == null) {
			__rect.width = __rect.height = 0;
		} else {
			__rect.width = Reflect.getProperty(root, "width");
			__rect.height = Reflect.getProperty(root, "height");
		}
		return super.__getRect();
	}
}
