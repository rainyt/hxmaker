package hx.display;

#if (spine_hx || spine_haxe)
import hx.geom.ColorTransform;
import hx.spine.SpineTypes.TrackEntry;
import hx.spine.SpineTypes.AnimationState;
import spine.Slot;
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
#end
