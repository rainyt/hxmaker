package hx.displays;

import hx.gemo.Matrix;
import hx.gemo.Rectangle;

/**
 * 可装载子对象的容器
 */
@:access(hx.displays.DisplayObject)
class DisplayObjectContainer extends DisplayObject {
	/**
	 * 该容器中的所有子对象
	 */
	@:noCompletion private var __children:Array<DisplayObject> = [];

	@:noCompletion private var __mouseChildren:Bool = true;

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

	override function __onAddToStage(stage:Stage):Void {
		super.__onAddToStage(stage);
		for (child in this.__children) {
			child.__onAddToStage(stage);
		}
	}

	override function __updateTransform(parent:DisplayObject) {
		super.__updateTransform(parent);
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
		if (!mouseEnabled) {
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
		return false;
	}

	override function getBounds(parent:Matrix = null):Rectangle {
		// 如果存在变换矩阵，则使用变换矩阵计算边界
		if (__transformDirty) {
			__updateTransform(null);
		}
		if (parent != null) {
			parent.concat(__transform);
		}
		var rect = new Rectangle();
		for (object in this.children) {
			var objectRect = object.getBounds(parent ?? __transform.clone());
			rect.expand(objectRect.x, objectRect.y, objectRect.width, objectRect.height);
		}
		return rect;
	}
}
