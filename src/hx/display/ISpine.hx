package hx.display;

import hx.geom.ColorTransform;
import spine.Slot;
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

interface ISpine {
	/**
	 * 设置Spine渲染器的刷新帧率，默认为60FPS
	 */
	public var renderFps(get, set):Int;

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
	dynamic public function onUpdateWorldTransformBefore():Void;

	/**
	 * 在updateWorldTransform调用之后发生
	 */
	dynamic public function onUpdateWorldTransformAfter():Void;

	/**
	 * 更新骨架
	 * @param delta 
	 */
	public function update(delta:Float):Void;

	/**
	 * 播放动画
	 * @param name 
	 * @param index 
	 * @param isLoop 
	 */
	public function play(name:String, index:Int = 0, isLoop:Bool = true):TrackEntry;

	/**
	 * 设置骨架皮肤
	 * @param name 
	 */
	public function setSkinByName(name:String):Void;
}

/**
 * Spine渲染接口实现，可使用该接口自定义Spine的渲染内容
 */
interface ISpineDrawOrder {
	public function onDrawOrder(slot:Slot, bitmapData:BitmapData, vertices:Array<Float>, triangles:Array<Int>, uvs:Array<Float>, alpha:Float,
		color:ColorTransform, applyBlendAddMode:Bool, isStart:Bool):Void;

	public function onStart():Void;

	public function onEnd():Void;
}
