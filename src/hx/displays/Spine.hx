package hx.displays;

import hx.events.Event;
import spine.atlas.TextureAtlasRegion;
import spine.attachments.MeshAttachment;
import spine.attachments.RegionAttachment;
import spine.attachments.ClippingAttachment;
import spine.SkeletonClipping;
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
	 * 剪切工具
	 */
	private static var clipper:SkeletonClipping = new SkeletonClipping();

	/**
	 * 常用矩阵顶点索引
	 */
	private static var quadTriangles:Array<Int> = [0, 1, 2, 2, 3, 0];

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
		skeleton.scaleY = -1;
		animationState = new AnimationState(new AnimationStateData(data));
		this.addEventListener(Event.UPDATE, onUpdateEvent);
		this.updateEnabled = true;
	}

	private function onUpdateEvent(e:Event):Void {
		this.update(1 / 60);
	}

	override function onInit() {
		super.onInit();
	}

	/**
	 * 在updateWorldTransform调用之前发生
	 */
	dynamic public function onUpdateWorldTransformBefore():Void {}

	/**
	 * 在updateWorldTransform调用之后发生
	 */
	dynamic public function onUpdateWorldTransformAfter():Void {}

	/**
	 * 更新骨架
	 * @param dt 
	 */
	public function update(delta:Float):Void {
		this.onUpdateWorldTransformBefore();
		animationState.update(delta);
		animationState.apply(skeleton);
		skeleton.update(delta);
		skeleton.updateWorldTransform(Physics.update);
		this.onUpdateWorldTransformAfter();
		// 清理遮罩数据
		clipper.clipEnd();
		var _tempVerticesArray:Array<Float> = [];
		var _uvs:Array<Float> = [];
		var _triangles:Array<Int> = [];
		var atlasRegion:TextureAtlasRegion = null;
		var bitmapData:BitmapData = null;
		this.clear();
		for (slot in skeleton.drawOrder) {
			if (slot.attachment != null) {
				// 不可见的情况下跳过
				if (slot.color.a == 0) {
					continue;
				}
				if (Std.isOfType(slot.attachment, ClippingAttachment)) {
					// 如果是剪切
					var region:ClippingAttachment = cast slot.attachment;
					clipper.clipStart(slot, region);
					continue;
				} else if (Std.isOfType(slot.attachment, RegionAttachment)) {
					// 如果是矩形
					var region:RegionAttachment = cast slot.attachment;
					_tempVerticesArray = [];
					region.computeWorldVertices(slot, _tempVerticesArray, 0, 2);
					_uvs = region.uvs;
					_triangles = quadTriangles.copy();
					atlasRegion = cast region.region;
				} else if (Std.isOfType(slot.attachment, MeshAttachment)) {
					// 如果是网格
					var region:MeshAttachment = cast slot.attachment;
					_tempVerticesArray = [];
					region.computeWorldVertices(slot, 0, region.worldVerticesLength, _tempVerticesArray, 0, 2);
					_uvs = region.uvs;
					_triangles = region.triangles.copy();
					atlasRegion = cast region.region;
				}
				// 裁剪实现
				if (clipper.isClipping()) {
					if (_triangles == null)
						continue;
					clipper.clipTriangles(_tempVerticesArray, _triangles, _triangles.length, _uvs);
					if (clipper.clippedTriangles.length == 0) {
						clipper.clipEndWithSlot(slot);
						continue;
					} else {
						var clippedVertices = clipper.clippedVertices;
						_tempVerticesArray = [];
						_uvs = [];
						var i = 0;
						while (true) {
							_tempVerticesArray.push(clippedVertices[i]);
							_tempVerticesArray.push(clippedVertices[i + 1]);
							_uvs.push(clippedVertices[i + 4]);
							_uvs.push(clippedVertices[i + 5]);
							i += 6;
							if (i >= clippedVertices.length)
								break;
						}
						_triangles = clipper.clippedTriangles;
					}
				}
				if (atlasRegion != null) {
					if (bitmapData != atlasRegion.texture) {
						bitmapData = atlasRegion.texture;
						this.beginBitmapData(bitmapData);
					}
					this.drawTriangles(_tempVerticesArray, _triangles, _uvs);
				}
				if (clipper.isClipping()) {
					clipper.clipEndWithSlot(slot);
				}
			}
		}
		this.setTransformDirty();
	}
}
