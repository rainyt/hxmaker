package hx.display;

import hx.geom.ColorTransform;
import spine.Slot;
import hx.display.ISpine.ISpineDrawOrder;
#if spine_hx
import spine.AnimationState.TrackEntry;
import spine.utils.SkeletonClipping;
import spine.AnimationState;
import spine.AnimationStateData;
import spine.support.graphics.TextureAtlas.AtlasRegion as TextureAtlasRegion;
#else
import spine.animation.TrackEntry;
import spine.atlas.TextureAtlasRegion;
import spine.SkeletonClipping;
import spine.Physics;
import spine.animation.AnimationStateData;
import spine.animation.AnimationState;
#end
import spine.attachments.MeshAttachment;
import spine.attachments.RegionAttachment;
import spine.attachments.ClippingAttachment;
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

	override function onUpdate(dt:Float) {
		this.spine.onUpdate(dt);
		for (object in __slotDisplay) {
			if (object.updateEnabled) {
				object.onUpdate(dt);
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

	private var __slotDisplay:Map<String, DisplayObject> = [];

	/**
	 * 绑定显示对象到slot
	 * @param slot 
	 * @param display 
	 */
	public function bindSlot(name:String, display:DisplayObject):Void {
		this.__slotDisplay[name] = display;
	}

	/**
	 * 获取slot绑定的显示对象
	 * @param slot 
	 * @return 
	 */
	public function getBindSoltDisplay(slot:Slot):DisplayObject {
		return this.__slotDisplay[slot.data.name];
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
		if (isStart) {
			__drawIndex = 0;
			for (graphics in __drawGraphics) {
				graphics.clear();
			}
			this.removeChildren();
		}

		if (bitmapData != null) {
			var g = getDrawGraphicsAt(__drawIndex);
			g.beginBitmapData(bitmapData);
			g.drawTriangles(vertices, triangles, uvs, alpha, color, applyBlendAddMode);
			this.addChild(g);
		}

		var display = getBindSoltDisplay(slot);
		if (display != null) {
			#if spine_hx
			display.x = slot.bone.getWorldX();
			display.y = slot.bone.getWorldY();
			display.rotation = slot.bone.getWorldRotationX();
			display.scaleX = slot.bone.getWorldScaleX();
			display.scaleY = slot.bone.getWorldScaleY();
			#else
			display.x = slot.bone.worldX;
			display.y = slot.bone.worldY;
			display.rotation = slot.bone.worldRotationX;
			display.scaleX = slot.bone.worldScaleX;
			display.scaleY = slot.bone.worldScaleY;
			#end
			this.addChild(display);
			__drawIndex++;
		}
	}
}
