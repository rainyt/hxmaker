package hx.display;

import hx.utils.ContextStats;
import hx.events.SpineEvent;
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
import hx.utils.ObjectPool;
import hx.geom.ColorTransform;
import hx.events.Event;
import spine.attachments.MeshAttachment;
import spine.attachments.RegionAttachment;
import spine.attachments.ClippingAttachment;
import spine.SkeletonData;
import spine.Skeleton;

/**
 * Spine渲染器支持，它依赖`spine-haxe4.2`版本
 */
@:keep
class Spine extends Graphics implements ISpine {
	/**
	 * 默认刷新帧率，可设置帧率，那么每次创建新的Spine实例时，会使用该帧率影响`renderFps`属性。
	 */
	public static var defaultFps = 60;

	/**
	 * 剪切工具
	 */
	private static var clipper:SkeletonClipping = new SkeletonClipping();

	/**
	 * 常用矩阵顶点索引
	 */
	private static var quadTriangles:Array<Int> = [0, 1, 2, 2, 3, 0];

	@:noCompletion private var __fps = 60;
	@:noCompletion private var __renderFpsTime:Float = 1 / 60;
	@:noCompletion private var __renderCurrentTime:Float = 0.;

	/**
	 * 对象池
	 */
	public var pool:ObjectPool<ColorTransform> = new ObjectPool(() -> {
		return new ColorTransform();
	}, (color) -> {
		color.alphaMultiplier = color.redMultiplier = color.blueMultiplier = color.greenMultiplier = 1;
		color.alphaOffset = color.redOffset = color.blueOffset = color.greenOffset = 0;
	});

	/**
	 * 设置Spine渲染器的刷新帧率，默认为60FPS
	 */
	public var renderFps(get, set):Int;

	private function get_renderFps():Int {
		return __fps;
	}

	private function set_renderFps(value:Int):Int {
		__renderFpsTime = 1 / value;
		__fps = value;
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

	private var __spineDrawDirty:Bool = true;

	/**
	 * 构造一个Spine渲染器
	 * @param data 
	 */
	public function new(data:SkeletonData) {
		super();
		skeleton = new Skeleton(data);
		skeleton.scaleY = -1;
		animationState = new AnimationState(new AnimationStateData(data));
		#if !spine_hx
		animationState.onComplete.add(onComplete);
		animationState.onEvent.add(onEvent);
		animationState.onStart.add(onStart);
		animationState.onEnd.add(onEnd);
		animationState.onDispose.add(onDispose);
		animationState.onInterrupt.add(onInterrupt);
		#end
		this.updateEnabled = true;
		this.renderFps = defaultFps;
	}

	#if !spine_hx
	private function onEvent(e:TrackEntry, s:spine.Event):Void {
		if (hasEventListener(SpineEvent.EVENT)) {
			var event = new SpineEvent(SpineEvent.EVENT);
			event.data = e;
			event.trackEntry = e;
			event.event = s;
			this.dispatchEvent(event);
		}
	}

	private function onComplete(e:TrackEntry):Void {
		if (hasEventListener(Event.COMPLETE)) {
			var event = new SpineEvent(Event.COMPLETE);
			event.data = e;
			event.trackEntry = e;
			this.dispatchEvent(event);
		}
	}

	private function onStart(e:TrackEntry):Void {
		if (hasEventListener(SpineEvent.START)) {
			var event = new SpineEvent(SpineEvent.START);
			event.data = e;
			event.trackEntry = e;
			this.dispatchEvent(event);
		}
	}

	private function onEnd(e:TrackEntry):Void {
		if (hasEventListener(SpineEvent.END)) {
			var event = new SpineEvent(SpineEvent.END);
			event.data = e;
			event.trackEntry = e;
			this.dispatchEvent(event);
		}
	}

	private function onDispose(e:TrackEntry):Void {
		if (hasEventListener(SpineEvent.DISPOSE)) {
			var event = new SpineEvent(SpineEvent.DISPOSE);
			event.data = e;
			event.trackEntry = e;
			this.dispatchEvent(event);
		}
	}

	private function onInterrupt(e:TrackEntry):Void {
		if (hasEventListener(SpineEvent.INTERRUPT)) {
			var event = new SpineEvent(SpineEvent.INTERRUPT);
			event.data = e;
			event.trackEntry = e;
			this.dispatchEvent(event);
		}
	}
	#end

	/**
	 * 是否必须在可见时进行渲染，如果设置为`true`，可设置该对象的`visible`属性为`false`来取消渲染，有助于提高性能。默认值为`false`。
	 */
	public var mustVisibleRender:Bool = false;

	override function onUpdate(dt:Float) {
		if (mustVisibleRender && !visible)
			return;
		if (!__playing && !__spineDrawDirty)
			return;
		__spineDrawDirty = false;
		__renderCurrentTime += dt;
		if (__fps >= 60 || __renderCurrentTime >= __renderFpsTime) {
			this.update(__renderCurrentTime);
			__renderCurrentTime = 0;
		}
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

	private var __spineDrawOrder:ISpineDrawOrder;

	/**
	 * 设置渲染容器，存在容器时，则将所有渲染对象添加到容器中
	 */
	public function setSpineDrawOrder(container:ISpineDrawOrder):Void {
		this.__spineDrawOrder = container;
	}

	/**
	 * 更新骨架
	 * @param dt 
	 */
	public function update(delta:Float):Void {
		ContextStats.statsSpineRenderCount();
		this.onUpdateWorldTransformBefore();
		animationState.update(delta);
		animationState.apply(skeleton);
		skeleton.update(delta);
		#if spine_haxe
		skeleton.updateWorldTransform(Physics.update);
		#else
		skeleton.updateWorldTransform();
		#end
		this.onUpdateWorldTransformAfter();
		// 清理遮罩数据
		clipper.clipEnd();
		var _tempVerticesArray:Array<Float> = [];
		var _uvs:Array<Float> = [];
		var _triangles:Array<Int> = [];
		var atlasRegion:TextureAtlasRegion = null;
		var bitmapData:BitmapData = null;
		@:privateAccess for (draw in this.__graphicsDrawData.draws) {
			switch draw {
				case BEGIN_FILL(color):
				case BEGIN_BITMAP_DATA(bitmapData, smoothing):
				case DRAW_TRIANGLE(vertices, indices, uvs, alpha, colorTransform, applyBlendAddMode):
					pool.release(colorTransform);
			}
		}
		this.clear();
		var isStartDarw = true;
		for (slot in skeleton.drawOrder) {
			if (slot.attachment != null #if spine_haxe && slot.data.visible #end) {
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
					#if spine_haxe
					region.computeWorldVertices(slot, _tempVerticesArray, 0, 2);
					_uvs = region.uvs;
					atlasRegion = cast region.region;
					#else
					region.computeWorldVertices(slot.bone, _tempVerticesArray, 0, 2);
					_uvs = region.getUVs();
					atlasRegion = cast region.getRegion();
					#end
					_triangles = quadTriangles.copy();
				} else if (Std.isOfType(slot.attachment, MeshAttachment)) {
					// 如果是网格
					var region:MeshAttachment = cast slot.attachment;
					_tempVerticesArray = [];
					region.computeWorldVertices(slot, 0, region.worldVerticesLength, _tempVerticesArray, 0, 2);
					#if spine_haxe
					_uvs = region.uvs;
					_triangles = region.triangles.copy();
					atlasRegion = cast region.region;
					#else
					_uvs = region.getUVs();
					_triangles = region.getTriangles();
					_triangles = _triangles.copy();
					atlasRegion = cast region.getRegion();
					#end
				}
				// 裁剪实现
				if (clipper.isClipping()) {
					if (_triangles == null)
						continue;
					#if spine_haxe
					clipper.clipTriangles(_tempVerticesArray, _triangles, _triangles.length, _uvs);
					var clippedVertices = clipper.clippedVertices.copy();
					var cliptriangles = clipper.clippedTriangles.copy();
					var usv = clipper.clippedUvs.copy();
					#else
					clipper.clipTriangles(_tempVerticesArray, _tempVerticesArray.length, _triangles, _triangles.length, _uvs, 1, 1, true);
					var clippedVertices:Array<Float> = clipper.getClippedVertices();
					var cliptriangles:Array<Int> = clipper.getClippedTriangles();
					#end
					if (clippedVertices.length == 0) {
						clipper.clipEndWithSlot(slot);
						continue;
					} else {
						#if spine_haxe
						_tempVerticesArray = clippedVertices;
						_uvs = usv;
						_triangles = cliptriangles;
						#else
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
						_triangles = cliptriangles;
						#end
					}
				}
				if (atlasRegion != null) {
					#if spine_haxe
					var texture = atlasRegion.texture;
					#else
					var texture = atlasRegion.rendererObject;
					#end
					// TODO 需要支持darkColor
					var c = pool.get();
					c.redMultiplier = slot.color.r;
					c.greenMultiplier = slot.color.g;
					c.blueMultiplier = slot.color.b;
					if (__spineDrawOrder != null) {
						__spineDrawOrder.onDrawOrder(slot, texture, _tempVerticesArray, _triangles, _uvs, slot.color.a, c,
							slot.data.blendMode == spine.BlendMode.additive, isStartDarw);
						isStartDarw = false;
					} else {
						if (bitmapData != texture) {
							bitmapData = texture;
							this.beginBitmapData(bitmapData);
						}
						this.drawTriangles(_tempVerticesArray, _triangles, _uvs, slot.color.a, c, slot.data.blendMode == spine.BlendMode.additive);
					}
				}
				if (clipper.isClipping()) {
					clipper.clipEndWithSlot(slot);
				}
			} else {
				if (__spineDrawOrder != null) {
					__spineDrawOrder.onDrawOrder(slot, null, null, null, null, 1, null, false, isStartDarw);
					isStartDarw = false;
				}
			}
		}
		this.setTransformDirty();
	}

	private var __playing = false;

	/**
	 * 播放动画
	 * @param name 
	 * @param index 
	 * @param isLoop 
	 */
	public function play(name:String, index:Int = 0, isLoop:Bool = true):TrackEntry {
		var t = this.animationState.getCurrent(index);
		if (t != null && t.animation.name == name)
			return t;
		__playing = true;
		return this.animationState.setAnimationByName(index, name, isLoop);
	}

	public function stop():Void {
		this.animationState.clearTracks();
		__playing = false;
	}

	/**
	 * 设置骨架皮肤
	 * @param name 
	 */
	public function setSkinByName(name:String):Void {
		#if spine_haxe
		this.skeleton.skinName = name;
		#else
		this.skeleton.setSkinByName(name);
		#end
		this.skeleton.setBonesToSetupPose();
		this.skeleton.setSlotsToSetupPose();
		__spineDrawDirty = true;
	}
}
