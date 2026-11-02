package hx.display;

#if (spine_hx || spine_haxe)
import hx.geom.ColorTransform;
import spine.Slot;
import hx.display.ISpine.ISpineDrawOrder;
import hx.spine.SpineTypes.TrackEntry;
import hx.spine.SpineTypes.AnimationState;
import spine.SkeletonData;
import spine.Skeleton;

/**
 * Spine精灵图容器渲染对象，通过`hx.display.Spine`提供渲染数据逻辑，在该容器中渲染数据。
 * 允许在不同的插槽中添加不同的显示对象。
 */
class SpineSprite extends Sprite implements ISpineDrawOrder {
	/**
	 * Spine容器渲染对象
	 */
	private var spine:Spine;

	/**
	 * 设置Spine渲染器的刷新帧率，默认为60FPS
	 */
	public var renderFps(get, set):Int;

	private function get_renderFps():Int {
		return spine.renderFps;
	}

	private function set_renderFps(value:Int):Int {
		spine.renderFps = value;
		return value;
	}

	override function set_colorTransform(value:ColorTransform):ColorTransform {
		spine.colorTransform = value;
		for (item in __slotDisplay) {
			for (sub in item) {
				sub.display.colorTransform = value;
			}
		}
		for (graphics in __drawGraphics) {
			if (graphics == null)
				continue;
			graphics.colorTransform = value;
		}
		return super.set_colorTransform(value);
	}

	/**
	 * 是否必须在可见时进行渲染，如果设置为`true`，可设置该对象的`visible`属性为`false`来取消渲染，有助于提高性能。默认值为`false`。
	 */
	public var mustVisibleRender(get, set):Bool;

	private function get_mustVisibleRender():Bool {
		return this.spine.mustVisibleRender;
	}

	private function set_mustVisibleRender(value:Bool):Bool {
		this.spine.mustVisibleRender = value;
		return value;
	}

	/**
	 * Spine骨架
	 */
	public var skeleton:Skeleton;

	/**
	 * 动画状态数据
	 */
	public var animationState:AnimationState;

	/**
	 * 在updateWorldTransform调用之前发生
	 */
	dynamic public function onUpdateWorldTransformBefore():Void {}

	/**
	 * 在updateWorldTransform调用之后发生
	 */
	dynamic public function onUpdateWorldTransformAfter():Void {}

	/**
	 * 构造一个Spine渲染器
	 * @param data 
	 */
	public function new(data:SkeletonData) {
		super();
		this.spine = new Spine(data);
		this.spine.updateEnabled = false;
		this.updateEnabled = true;
		this.skeleton = this.spine.skeleton;
		this.animationState = this.spine.animationState;
		this.spine.onUpdateWorldTransformBefore = this.__onUpdateWorldTransformBefore;
		this.spine.onUpdateWorldTransformAfter = this.__onUpdateWorldTransformAfter;
		this.spine.setSpineDrawOrder(this);
	}

	private function __onUpdateWorldTransformBefore():Void {
		this.onUpdateWorldTransformBefore();
	}

	private function __onUpdateWorldTransformAfter():Void {
		this.onUpdateWorldTransformAfter();
	}

	override function onUpdate(dt:Float):Void {
		this.spine.onUpdate(dt);
		for (object in __slotDisplay) {
			for (sub in object) {
				if (sub.display.updateEnabled) {
					sub.display.onUpdate(dt);
				}
			}
		}
	}

	/**
	 * 更新骨架
	 * @param delta 
	 */
	public function update(delta:Float):Void {
		this.spine.update(delta);
	}

	/**
	 * 播放动画
	 * @param name 
	 * @param index 
	 * @param isLoop 
	 */
	public function play(name:String, index:Int = 0, isLoop:Bool = true):TrackEntry {
		return this.spine.play(name, index, isLoop);
	}

	/** 停止动画并保留当前姿势。 */
	public function stop():Void {
		this.spine.stop();
	}

	/**
	 * 设置骨架皮肤
	 * @param name 
	 */
	public function setSkinByName(name:String):Void {
		this.spine.setSkinByName(name);
	}

	private var __drawGraphics:Array<Graphics> = [];

	private var __drawIndex:Int = 0;

	private function getDrawGraphicsAt(i:Int):Graphics {
		if (__drawGraphics[i] == null) {
			__drawGraphics[i] = new Graphics();
		}
		return __drawGraphics[i];
	}

	private var __slotDisplay:Map<String, Array<DisplayObjectDraw>> = [];

	/**
	 * 绑定显示对象到slot
	 * @param slot 
	 * @param display 
	 */
	public function bindSlot(name:String, display:DisplayObject, ?draw:DisplayObject->Void):Void {
		#if debug
		if (this.skeleton.findSlot(name) == null)
			throw 'slot $name not found';
		#end
		if (this.__slotDisplay[name] == null)
			this.__slotDisplay[name] = [];
		this.__slotDisplay[name].push({
			display: display,
			drawFunction: draw
		});
	}

	/**
	 * 移除slot显示对象
	 * @param display 
	 */
	public function removeBindSlot(display:DisplayObject):Void {
		for (array in __slotDisplay) {
			for (index => item in array) {
				if (item.display == display) {
					array.splice(index, 1);
					return;
				}
			}
		}
	}

	/**
	 * 解绑slot
	 * @param slot 
	 */
	public function unbindSlot(name:String):Void {
		this.__slotDisplay.remove(name);
	}

	/**
	 * 清除所有绑定的slot显示对象
	 */
	public function clearAllBindSlots():Void {
		this.__slotDisplay = [];
	}

	/**
	 * 获取slot绑定的显示对象
	 * @param slot 
	 * @return 
	 */
	public function getBindSoltDisplay(slot:Slot):Array<DisplayObjectDraw> {
		return this.getBindSoltDisplayByName(slot.data.name);
	}

	/**
	 * 获取slot绑定的显示对象
	 * @param name 
	 * @return 
	 */
	public function getBindSoltDisplayByName(name:String):Array<DisplayObjectDraw> {
		if (this.__slotDisplay[name] == null)
			return null;
		return this.__slotDisplay[name];
	}

	public function onStart():Void {
		__drawIndex = 0;
		for (graphics in __drawGraphics) {
			if (graphics != null)
				graphics.clear();
		}
		// 即使整帧没有可绘制插槽，也要移除上一帧的内容。
		this.removeChildren();
	}

	public function onEnd():Void {
		__colorTransformDirty = false;
	}

	/**
	 * 自定义渲染处理
	 * @param slot 
	 * @param bitmapData 
	 * @param vertices 
	 * @param triangles 
	 * @param uvs 
	 * @param alpha 
	 * @param color 
	 * @param applyBlendAddMode 
	 */
	public function onDrawOrder(slot:Slot, bitmapData:BitmapData, vertices:Array<Float>, triangles:Array<Int>, uvs:Array<Float>, alpha:Float,
			color:ColorTransform, applyBlendAddMode:Bool, isStart:Bool):Void {
		var isDarwable:Bool = bitmapData != null;

		if (isDarwable) {
			// 每个插槽使用独立图形，防止后续插槽覆盖此前提交的数据。
			var g:Graphics = getDrawGraphicsAt(__drawIndex++);
			g.colorTransform = this.colorTransform;
			g.beginBitmapData(bitmapData);
			g.drawTriangles(vertices, triangles, uvs, alpha, color, applyBlendAddMode);
			this.addChild(g);
		}

		var datas:Array<DisplayObjectDraw> = getBindSoltDisplay(slot);
		if (datas != null) {
			for (data in datas) {
				var display:DisplayObject = data == null ? null : data.display;
				if (display != null) {
					#if spine_hx
					display.x = slot.bone.getWorldX();
					display.y = slot.bone.getWorldY();
					display.rotation = slot.bone.getWorldRotationX();
					display.scaleX = slot.bone.getWorldScaleX();
					display.scaleY = slot.bone.getWorldScaleY();
					display.alpha = slot.color.a;
					#else
					display.x = slot.bone.worldX;
					display.y = slot.bone.worldY;
					display.rotation = slot.bone.worldRotationX;
					display.scaleX = slot.bone.worldScaleX;
					display.scaleY = slot.bone.worldScaleY;
					display.alpha = slot.color.a;
					#end
					this.addChild(display);
					if (data.drawFunction != null) {
						data.drawFunction(display);
					}
				}
			}
		}
	}

	override public function dispose():Void {
		if (isDisposed)
			return;
		updateEnabled = false;
		super.dispose();
		spine.dispose();
		for (graphics in __drawGraphics) {
			if (graphics != null && !graphics.isDisposed)
				graphics.dispose();
		}
		__drawGraphics.resize(0);
		__slotDisplay.clear();
	}

	override function addEventListener<T>(type:String, listener:T->Void):Void {
		spine.addEventListener(type, listener);
	}

	override function removeEventListener<T>(type:String, listener:T->Void):Void {
		spine.removeEventListener(type, listener);
	}
}

typedef DisplayObjectDraw = {
	display:DisplayObject,
	drawFunction:DisplayObject->Void
}
#end
