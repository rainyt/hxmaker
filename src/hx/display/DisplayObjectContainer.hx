package hx.display;

import hx.layout.ILayout;
import hx.gemo.Matrix;
import hx.gemo.Rectangle;

/**
 * 可装载子对象的容器
 */
@:access(hx.display.DisplayObject)
class DisplayObjectContainer extends DisplayObject {
	/**
	 * 该容器中的所有子对象
	 */
	@:noCompletion private var __children:Array<DisplayObject> = [];

	@:noCompletion private var __mouseChildren:Bool = true;
	@:noCompletion private var __layout:ILayout;
	@:noCompletion private var __layoutDirty:Bool = false;

	/**
	 * 布局
	 */
	public var layout(get, set):ILayout;

	private function set_layout(value:ILayout):ILayout {
		__layout = value;
		return value;
	}

	private function get_layout():ILayout {
		return __layout;
	}

	private function __updateLayout() {
		if (__layoutDirty) {
			__layoutDirty = false;
			updateLayout();
		}
	}

	/**
	 * 更新布局
	 */
	public function updateLayout():Void {
		if (layout != null) {
			layout.update(this.children);
		}
		for (object in this.children) {
			if (object is DisplayObjectContainer) {
				cast(object, DisplayObjectContainer).updateLayout();
			}
		}
	}

	/**
	 * 当前显示对象是否允许子对象被触摸，如果返回false，则返回当前显示对象
	 */
	public var mouseChildren(get, set):Bool;

	private function set_mouseChildren(value:Bool):Bool {
		__mouseChildren = value;
		return value;
	}

	private function get_mouseChildren():Bool {
		return __mouseChildren;
	}

	public function new() {
		super();
		this.updateEnabled = true;
	}

	/**
	 * 获得容器的显示对象列表
	 */
	public var children(get, never):Array<DisplayObject>;

	private function get_children():Array<DisplayObject> {
		return this.__children;
	}

	/**
	 * 添加到当前容器中
	 * @param child 
	 */
	public function addChild(child:DisplayObject):Void {
		this.addChildAt(child, this.__children.length);
	}

	/**
	 * 根据索引添加到当前容器中
	 * @param child 
	 * @param index 
	 */
	public function addChildAt(child:DisplayObject, index:Int):Void {
		if (index < 0) {
			index = 0;
		} else if (index > this.__children.length) {
			index = this.__children.length;
		}
		if (child.parent != null) {
			child.parent.removeChild(child);
		}
		this.__children.insert(index, child);
		child.__parent = this;
		// 追加舞台处理
		if (this.stage != null && child.stage == null) {
			child.__onAddToStage(this.stage);
		}
		this.__layoutDirty = true;
		this.setDirty();
	}

	/**
	 * 删除显示对象
	 * @param child 
	 */
	public function removeChild(child:DisplayObject):Void {
		this.__children.remove(child);
		child.onRemoveToStage();
		child.__parent = null;
		child.__stage = null;
		this.__layoutDirty = true;
		this.setDirty();
	}

	/**
	 * 删除指定索引的显示对象
	 * @param index 
	 */
	public function removeChildAt(index:Int):Void {
		var child:DisplayObject = this.__children[index];
		if (child != null) {
			removeChild(child);
		}
	}

	/**
	 * 删除指定索引范围的显示对象
	 * @param start 
	 * @param end 
	 */
	public function removeChildren(start:Int = 0, end:Int = -1):Void {
		var len = end == -1 ? this.__children.length : end;
		while (start < len) {
			removeChildAt(start);
			start++;
		}
	}

	/**
	 * 获得显示对象列表
	 * @param index 
	 * @return DisplayObject
	 */
	public function getChildAt(index:Int):DisplayObject {
		return this.__children[index];
	}

	/**
	 * 根据名称获得子对象
	 * @param name 
	 * @return DisplayObject
	 */
	public function getChildByName(name:String):DisplayObject {
		for (object in this.__children) {
			if (object.name == name) {
				return object;
			}
		}
		return null;
	}

	override function __onAddToStage(stage:Stage):Void {
		super.__onAddToStage(stage);
		for (child in this.__children) {
			child.__onAddToStage(stage);
		}
	}

	override function __updateTransform(parent:DisplayObject) {
		super.__updateTransform(parent);
		this.__updateLayout();
		for (child in this.__children) {
			child.__updateTransform(this);
		}
	}

	override function onUpdate(dt:Float) {
		super.onUpdate(dt);
		for (child in this.__children) {
			if (child.updateEnabled) {
				child.onUpdate(dt);
			}
		}
	}

	override function hitTestWorldPoint(x:Float, y:Float):Bool {
		var i = this.children.length;
		while (i-- > 0) {
			var display = this.children[i];
			if (display.hitTestWorldPoint(x, y)) {
				return true;
			}
		}
		return false;
	}

	override function __hitTest(x:Float, y:Float, stacks:Array<DisplayObject>):Bool {
		if (!mouseEnabled || !this.visible) {
			return false;
		}
		var i = this.children.length;
		stacks.push(this);
		while (i-- > 0) {
			var display = this.children[i];
			if (display.__hitTest(x, y, stacks)) {
				if (!this.mouseChildren) {
					stacks.pop();
				}
				return true;
			}
		}
		stacks.pop();
		return false;
	}

	override function getBounds(parent:Matrix = null):Rectangle {
		if (parent != null) {
			var t = __transform.clone();
			t.concat(parent);
			parent = t;
		}
		__updateLayout();
		var rect = new Rectangle();
		for (object in this.children) {
			var objectRect = object.getBounds(parent != null ? parent : __transform.clone());
			rect.expand(objectRect.x, objectRect.y, objectRect.width, objectRect.height);
		}
		return rect;
	}

	/**
	 * 该容器内所有子对象的数量。
	 */
	public var numChildren(get, never):Int;

	private function get_numChildren():Int {
		return __children.length;
	}

	override function setTransformDirty(value:Bool = true) {
		super.setTransformDirty(value);
		for (object in this.children) {
			object.setTransformDirty();
		}
	}

	override function set_width(value:Float):Float {
		__layoutDirty = true;
		return super.set_width(value);
	}

	override function set_height(value:Float):Float {
		__layoutDirty = true;
		return super.set_height(value);
	}
}
