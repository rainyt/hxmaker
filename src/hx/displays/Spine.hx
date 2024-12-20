package hx.displays;

import spine.Physics;
import spine.animation.AnimationStateData;
import spine.animation.AnimationState;
import spine.SkeletonData;
import spine.Skeleton;

/**
 * Spine渲染器支持，它依赖`spine-haxe4.2`版本
 */
class Spine extends Graphic {
	/**
	 * Spine骨架
	 */
	public var skeleton:Skeleton;

	/**
	 * 动画状态数据
	 */
	public var animationState:AnimationState;

	/**
	 * 构造一个Spine渲染器
	 * @param data 
	 */
	public function new(data:SkeletonData) {
		super();
		skeleton = new Skeleton(data);
		animationState = new AnimationState(new AnimationStateData(data));
	}

	override function onInit() {
		super.onInit();
	}

	/**
	 * 更新骨架
	 * @param dt 
	 */
	public function update(delta:Float):Void {
		animationState.update(delta);
		animationState.apply(skeleton);
		skeleton.update(delta);
		skeleton.updateWorldTransform(Physics.update);
	}
}
