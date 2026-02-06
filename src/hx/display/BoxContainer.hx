package hx.display;

import hx.layout.ILayout;

/**
 * 容器箱子类
 * 该容器会有一个独立的box，该box会包含所有的子元素
 * 提供了更灵活的子元素管理方式
 */
class BoxContainer extends Box {
	/**
	 * 容器显示对象，所有子元素都会被添加到这个box中
	 */
	public var box:Box = new Box();

	/**
	 * 初始化容器
	 * 在创建时自动将内部box添加到容器中
	 */
	override function onInit() {
		super.onInit();
		super.addChildAt(box, 0);
	}

	/**
	 * 设置布局
	 * 同时设置内部box的布局
	 * @param value 布局对象
	 * @return 设置的布局对象
	 */
	override function set_layout(value:ILayout):ILayout {
		box.layout = value;
		return super.set_layout(value);
	}

	/**
	 * 获取子元素数量
	 * 返回内部box的子元素数量
	 * @return 子元素数量
	 */
	override function get_numChildren():Int {
		return box.get_numChildren();
	}

	/**
	 * 调用父类的addChildAt方法
	 * @param display 要添加的显示对象
	 * @param index 添加的位置索引
	 */
	private function superAddChildAt(display:DisplayObject, index:Int):Void {
		super.addChildAt(display, index);
	}

	/**
	 * 调用父类的removeChild方法
	 * @param child 要移除的显示对象
	 */
	private function superRemoveChild(child:DisplayObject):Void {
		super.removeChild(child);
	}

	/**
	 * 添加子元素
	 * 将子元素添加到内部box中
	 * @param child 要添加的显示对象
	 */
	override function addChild(child:DisplayObject) {
		box.addChild(child);
	}

	/**
	 * 在指定位置添加子元素
	 * 将子元素添加到内部box的指定位置
	 * @param child 要添加的显示对象
	 * @param index 添加的位置索引
	 */
	override function addChildAt(child:DisplayObject, index:Int) {
		box.addChildAt(child, index);
	}

	/**
	 * 获取指定位置的子元素
	 * 返回内部box中指定位置的子元素
	 * @param index 子元素的位置索引
	 * @return 指定位置的显示对象
	 */
	override function getChildAt(index:Int):DisplayObject {
		return box.getChildAt(index);
	}

	/**
	 * 根据名称获取子元素
	 * 返回内部box中指定名称的子元素
	 * @param name 子元素的名称
	 * @return 指定名称的显示对象
	 */
	override function getChildByName(name:String):DisplayObject {
		return box.getChildByName(name);
	}

	/**
	 * 获取子元素的位置索引
	 * 返回子元素在内部box中的位置索引
	 * @param child 要查找的显示对象
	 * @return 子元素的位置索引
	 */
	override function getChildIndexAt(child:DisplayObject):Int {
		return box.getChildIndexAt(child);
	}

	/**
	 * 移除子元素
	 * 从内部box中移除指定的子元素
	 * @param child 要移除的显示对象
	 */
	override function removeChild(child:DisplayObject) {
		box.removeChild(child);
	}

	/**
	 * 移除指定位置的子元素
	 * 从内部box中移除指定位置的子元素
	 * @param index 要移除的子元素位置索引
	 */
	override function removeChildAt(index:Int) {
		box.removeChildAt(index);
	}

	/**
	 * 移除多个子元素
	 * 从内部box中移除指定范围的子元素
	 * @param start 起始位置索引，默认为0
	 * @param end 结束位置索引，默认为-1（表示到最后）
	 */
	override function removeChildren(start:Int = 0, end:Int = -1) {
		box.removeChildren(start, end);
	}

	/**
	 * 获取所有子元素
	 * 返回内部box的所有子元素
	 * @return 子元素数组
	 */
	override function get_children():Array<DisplayObject> {
		return box.children;
	}

	/**
	 * 设置宽度
	 * 同时设置内部box的宽度
	 * @param value 要设置的宽度值
	 * @return 设置后的宽度值
	 */
	override function set_width(value:Float):Float {
		box.width = value;
		return super.set_width(value);
	}

	/**
	 * 设置高度
	 * 同时设置内部box的高度
	 * @param value 要设置的高度值
	 * @return 设置后的高度值
	 */
	override function set_height(value:Float):Float {
		box.height = value;
		return super.set_height(value);
	}

	/**
	 * 更新布局
	 * 更新内部box的布局
	 */
	override function updateLayout() {
		this.box.updateLayout();
	}
}
