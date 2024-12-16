package hx.displays;

/**
 * 可装载子对象的容器
 */
@:access(hx.displays.DisplayObject)
class DisplayObjectContainer extends DisplayObject {
	/**
	 * 该容器中的所有子对象
	 */
	@:noCompletion private var __children:Array<DisplayObject> = [];

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
}
