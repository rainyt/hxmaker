package hx.display;

import hx.geom.Point;
import hx.events.Event;
import hx.ui.UIManager;
import hx.layout.ILayout;
import hx.geom.Matrix;
import hx.geom.Rectangle;

/**
 * 可装载子对象的容器
 */
@:keep
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
		if (__layout != null) {
			__layout.parent = this;
		}
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
			layout.update(this.children.filter((object) -> !object.hide));
		}
		for (object in this.children) {
			if (object is DisplayObjectContainer) {
				cast(object, DisplayObjectContainer).updateLayout();
			}
		}
	}

	/**
	 * 是否容器也可以被点击，当容器内的对象无法正常点击时，该值为`true`时，则可以触发容器的点击事件，默认值为`false`
	 */
	public var mouseClickEnabled:Bool = false;

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

	/**
	 * 构造UI
	 */
	override private function onBuildUI():Void {
		// 检测是否存在__ui_id__，如果存在则需要通过UIManager进行构造
		var __ui_id__ = Reflect.getProperty(this, "__ui_id__");
		if (__ui_id__ != null) {
			UIManager.getInstance().buildUi(__ui_id__, this);
		}
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
		if (child == null) {
			throw "ArgumentError: child is null.";
		}
		if (index < 0) {
			index = 0;
		} else if (index > this.__children.length) {
			index = this.__children.length;
		}
		if (child.parent != null) {
			child.parent.removeChild(child);
		}
		var isOneAddToStage = child.__parent == null;
		this.__children.insert(index, child);
		child.__parent = this;
		// 追加舞台处理
		if (isOneAddToStage && this.stage != null && child.stage == null) {
			child.__onAddToStage(this.stage);
		}
		if (this.hasEventListener(Event.ADDED)) {
			var event = new Event(Event.ADDED);
			event.target = child;
			this.dispatchEvent(event);
		}
		this.__layoutDirty = true;
		this.setDirty();
	}

	/**
	 * 删除显示对象
	 * @param child 
	 */
	public function removeChild(child:DisplayObject):Void {
		if (this.__children.remove(child)) {
			if (child.__parent != null)
				child.onRemoveToStage();
			if (child.hasEventListener(Event.REMOVED_FROM_STAGE))
				child.dispatchEvent(new Event(Event.REMOVED_FROM_STAGE));
			if (this.hasEventListener(Event.REMOVED)) {
				var event = new Event(Event.REMOVED);
				event.target = child;
				this.dispatchEvent(event);
			}
			child.__parent = null;
			child.__onRemoveFromStage();
			this.__layoutDirty = true;
			this.setDirty();
		}
	}

	override function onRemoveToStage() {
		super.onRemoveToStage();
		for (child in this.__children) {
			child.onRemoveToStage();
		}
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
		while (len > start) {
			len--;
			removeChildAt(len);
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
	 * 获得显示对象索引
	 * @param child 
	 * @return Int
	 */
	public function getChildIndexAt(child:DisplayObject):Int {
		for (i in 0...this.__children.length) {
			if (this.__children[i] == child) {
				return i;
			}
		}
		return -1;
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

	override function __onRemoveFromStage():Void {
		super.__onRemoveFromStage();
		for (child in this.__children) {
			child.__onRemoveFromStage();
		}
	}

	override function __updateTransform(parent:DisplayObject) {
		super.__updateTransform(parent);
		this.__updateLayout();
		if (this.background != null) {
			this.background.__updateTransform(this);
		}
		for (child in this.__children) {
			child.__updateTransform(this);
		}
	}

	override function onUpdate(dt:Float) {
		super.onUpdate(dt);
		var copyChildren = this.__children.copy();
		for (child in copyChildren) {
			if (child.updateEnabled) {
				child.onUpdate(dt);
			}
		}
	}

	override function hitTestWorldPoint(x:Float, y:Float):Bool {
		if (maskRect != null) {
			// 必须命中在maskRect之内的区域
			var rect = this.__getWorldLocalBounds(maskRect);
			if (!rect.containsPoint(x, y)) {
				return false;
			}
		}
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
		if (maskRect != null) {
			// 必须命中在maskRect之内的区域
			var rect = this.__getWorldLocalBounds(maskRect);
			if (!rect.containsPoint(x, y)) {
				return false;
			}
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
		if (mouseClickEnabled) {
			return true;
		}
		stacks.pop();
		return false;
	}

	override function getBounds(parent:DisplayObject = null):Rectangle {
		__updateLayout();
		var rect = new Rectangle();
		for (object in this.children) {
			if (object.hide)
				continue;
			var objectRect = object.getBounds(parent);
			if (objectRect.width > 0 && objectRect.height > 0)
				rect.expand(objectRect.x, objectRect.y, objectRect.width, objectRect.height);
		}
		return rect;
	}

	override private function __getBounds(parent:Matrix = null):Rectangle {
		__updateLayout();
		if (parent != null) {
			var t = __transform.clone();
			t.concat(parent);
			parent = t;
		}
		var rect = new Rectangle();
		for (object in this.children) {
			if (object.hide)
				continue;
			var objectRect = object.__getBounds(parent != null ? parent : __transform.clone());
			if (objectRect.width > 0 && objectRect.height > 0)
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
		// for (object in this.children) {
		// object.setTransformDirty();
		// }
	}

	override function set_width(value:Float):Float {
		__layoutDirty = true;
		return super.set_width(value);
	}

	override function set_height(value:Float):Float {
		__layoutDirty = true;
		return super.set_height(value);
	}

	override public function dispose():Void {
		super.dispose();
		for (child in this.__children) {
			child.dispose();
		}
	}

	public var mouseX(get, never):Float;

	private function get_mouseX():Float {
		if (stage != null)
			return this.globalToLocal(new Point(stage.__stageX, 0)).x;
		return 0;
	}

	public var mouseY(get, never):Float;

	private function get_mouseY():Float {
		if (stage != null)
			return this.globalToLocal(new Point(0, stage.__stageY)).y;
		return 0;
	}

	/**
	 * 交换两个子对象的位置
	 * @param childA 
	 * @param childB 
	 */
	public function swapChildren(childA:DisplayObject, childB:DisplayObject) {
		var indexA = getChildIndexAt(childA);
		var indexB = getChildIndexAt(childB);
		if (indexA != -1 && indexB != -1) {
			this.children[indexA] = childB;
			this.children[indexB] = childA;
		}
	}
}
