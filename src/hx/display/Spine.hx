package hx.display;

#if (spine_hx || spine_haxe)
import hx.utils.ContextStats;
import hx.events.SpineEvent;
import hx.display.ISpine.ISpineDrawOrder;
import hx.spine.SpineTypes.TrackEntry;
import hx.spine.SpineTypes.AnimationState;
import hx.spine.SpineTypes.AnimationStateData;
import hx.spine.SpineTypes.SkeletonClipping;
import hx.spine.SpineTypes.TextureAtlasRegion;
import hx.spine.SpineTypes.AttachmentColor;
import hx.utils.ObjectPool;
import hx.geom.ColorTransform;
import hx.events.Event;
#if spine_haxe
import spine.Physics;
#end
import spine.attachments.MeshAttachment;
import spine.attachments.RegionAttachment;
import spine.attachments.ClippingAttachment;
import spine.SkeletonData;
import spine.Skeleton;

/**
 * 按依赖库选择 Spine 渲染路径：spine-hx 3.8.x 或 spine-haxe 4.2.x。
 */
@:keep
@:build(hx.macro.SpineMacro.build())
class Spine extends Graphics implements ISpine {
	/** 当前编译选择的运行时，不需要额外定义切换开关。 */
	public static inline var runtimeName:String = #if spine_hx "spine-hx 3.8" #else "spine-haxe 4.2" #end;
	/**
	 * 默认刷新帧率，可设置帧率，那么每次创建新的Spine实例时，会使用该帧率影响`renderFps`
	 */
	public static var defaultFps:Int = 60;

	/**
	 * 剪切工具
	 */
	private var clipper:SkeletonClipping = new SkeletonClipping();

	/**
	 * 常用矩阵顶点索引
	 */
	private static var quadTriangles:Array<Int> = [0, 1, 2, 2, 3, 0];

	@:noCompletion private var __fps:Int = 60;
	@:noCompletion private var __renderFpsTime:Float = 1 / 60;
	@:noCompletion private var __renderCurrentTime:Float = 0.;

	/**
	 * 对象池
	 */
	public var pool:ObjectPool<ColorTransform> = new ObjectPool(() -> {
		return new ColorTransform();
	}, (color:ColorTransform) -> {
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
		if (value <= 0)
			throw "Spine 刷新帧率必须大于零";
		__renderFpsTime = 1 / value;
		__fps = value;
		return value;
	}

	override function set_width(value:Float):Float {
		if (useBoundsSize)
			return super.set_width(value);
		__width = value;
		return value;
	}

	/**
	 * 使用骨架的bounds来设置Spine渲染器的宽高，默认值为`false`，如果设置为`true`，则会使用骨架的bounds来设置Spine渲染器的宽高
	**/
	public var useBoundsSize:Bool = false;

	override function get_width():Float {
		if (!useBoundsSize && __width != null)
			return __width;
		return super.get_width();
	}

	override function set_height(value:Float):Float {
		if (useBoundsSize)
			return super.set_height(value);
		__height = value;
		return value;
	}

	override function get_height():Float {
		if (__height != null)
			return __height;
		return super.get_height();
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
	private var __drawColors:Array<ColorTransform> = [];
	#if spine_hx
	private var __listener:Spine38Listener;
	#end

	/**
	 * 构造一个Spine渲染器
	 * @param data 
	 */
	public function new(data:SkeletonData) {
		super();
		skeleton = new Skeleton(data);
		skeleton.scaleY = -1;
		animationState = new AnimationState(new AnimationStateData(data));
		#if spine_hx
		__listener = new Spine38Listener(this);
		animationState.addListener(__listener);
		#else
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

	private function onEvent(e:TrackEntry, s:spine.Event):Void {
		if (hasEventListener(SpineEvent.EVENT)) {
			var event:SpineEvent = new SpineEvent(SpineEvent.EVENT);
			event.data = e;
			event.trackEntry = e;
			event.event = s;
			this.dispatchEvent(event);
		}
	}

	private function onComplete(e:TrackEntry):Void {
		if (hasEventListener(Event.COMPLETE)) {
			var event:SpineEvent = new SpineEvent(Event.COMPLETE);
			event.data = e;
			event.trackEntry = e;
			this.dispatchEvent(event);
		}
	}

	private function onStart(e:TrackEntry):Void {
		if (hasEventListener(SpineEvent.START)) {
			var event:SpineEvent = new SpineEvent(SpineEvent.START);
			event.data = e;
			event.trackEntry = e;
			this.dispatchEvent(event);
		}
	}

	private function onEnd(e:TrackEntry):Void {
		if (hasEventListener(SpineEvent.END)) {
			var event:SpineEvent = new SpineEvent(SpineEvent.END);
			event.data = e;
			event.trackEntry = e;
			this.dispatchEvent(event);
		}
	}

	private function onDispose(e:TrackEntry):Void {
		if (hasEventListener(SpineEvent.DISPOSE)) {
			var event:SpineEvent = new SpineEvent(SpineEvent.DISPOSE);
			event.data = e;
			event.trackEntry = e;
			this.dispatchEvent(event);
		}
	}

	private function onInterrupt(e:TrackEntry):Void {
		if (hasEventListener(SpineEvent.INTERRUPT)) {
			var event:SpineEvent = new SpineEvent(SpineEvent.INTERRUPT);
			event.data = e;
			event.trackEntry = e;
			this.dispatchEvent(event);
		}
	}

	/**
	 * 是否必须在可见时进行渲染，如果设置为`true`，可设置该对象的`visible`属性为`false`来取消渲染，有助于提高性能。默认值为`false`。
	 */
	public var mustVisibleRender:Bool = false;

	override function onUpdate(dt:Float):Void {
		if (mustVisibleRender && !visible)
			return;
		if (!__playing && !__spineDrawDirty)
			return;
		__renderCurrentTime += dt;
		if (__spineDrawDirty || __fps >= 60 || __renderCurrentTime >= __renderFpsTime) {
			this.update(__renderCurrentTime);
			__renderCurrentTime = 0;
			__spineDrawDirty = false;
		}
	}

	override function onInit():Void {
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
		clipper.clipEnd();
		if (__spineDrawOrder != null)
			__spineDrawOrder.onStart();
		clearDrawData();
		var isStart:Bool = true;
		for (slot in skeleton.drawOrder) {
			var drawable:Bool = slot.bone.active && slot.attachment != null;
			#if spine_haxe
			drawable = drawable && slot.data.visible;
			#end
			if (drawable && Std.isOfType(slot.attachment, ClippingAttachment)) {
				clipper.clipStart(slot, cast slot.attachment);
			} else {
				var drawn:Bool = drawable && drawSlot(slot, isStart);
				if (!drawn && __spineDrawOrder != null)
					__spineDrawOrder.onDrawOrder(slot, null, null, null, null, 1, null, false, isStart);
				// 空附件、透明插槽和不支持的附件也必须结束对应的裁剪范围。
				clipper.clipEndWithSlot(slot);
				isStart = false;
			}
		}
		clipper.clipEnd();
		if (__spineDrawOrder != null)
			__spineDrawOrder.onEnd();
		this.setTransformDirty();
	}

	/** 只回收本对象创建的颜色，同时覆盖普通绘制和插槽容器绘制。 */
	private function clearDrawData():Void {
		this.clear();
		for (color in __drawColors)
			pool.release(color);
		__drawColors.resize(0);
	}

	/** 每个插槽独立生成数据，避免复用上一插槽的纹理或顶点。 */
	private function drawSlot(slot:spine.Slot, isStart:Bool):Bool {
		if (slot.color.a == 0 || skeleton.color.a == 0)
			return false;
		var vertices:Array<Float> = [];
		var uvs:Array<Float>;
		var triangles:Array<Int>;
		var atlasRegion:TextureAtlasRegion;
		var attachmentColor:AttachmentColor;
		if (Std.isOfType(slot.attachment, RegionAttachment)) {
			var region:RegionAttachment = cast slot.attachment;
			vertices.resize(8);
			#if spine_haxe
			region.computeWorldVertices(slot, vertices, 0, 2);
			uvs = region.uvs;
			atlasRegion = cast region.region;
			attachmentColor = region.color;
			#else
			region.computeWorldVertices(slot.bone, vertices, 0, 2);
			uvs = region.getUVs();
			atlasRegion = cast region.getRegion();
			attachmentColor = region.getColor();
			#end
			triangles = quadTriangles.copy();
		} else if (Std.isOfType(slot.attachment, MeshAttachment)) {
			var mesh:MeshAttachment = cast slot.attachment;
			vertices.resize(mesh.worldVerticesLength);
			mesh.computeWorldVertices(slot, 0, mesh.worldVerticesLength, vertices, 0, 2);
			#if spine_haxe
			uvs = mesh.uvs;
			triangles = mesh.triangles.copy();
			atlasRegion = cast mesh.region;
			attachmentColor = mesh.color;
			#else
			uvs = mesh.getUVs();
			var meshTriangles:Array<Int> = mesh.getTriangles();
			triangles = meshTriangles.copy();
			atlasRegion = cast mesh.getRegion();
			attachmentColor = mesh.getColor();
			#end
		} else {
			return false;
		}
		if (atlasRegion == null || attachmentColor.a == 0)
			return false;
		if (clipper.isClipping()) {
			#if spine_haxe
			clipper.clipTriangles(vertices, triangles, triangles.length, uvs);
			vertices = clipper.clippedVertices.copy();
			triangles = clipper.clippedTriangles.copy();
			uvs = clipper.clippedUvs.copy();
			#else
			// 3.8 输出按 x、y、亮色、暗色、u、v 排列，需拆成 Graphics 接口的数据。
			clipper.clipTriangles(vertices, vertices.length, triangles, triangles.length, uvs, 1, 1, true);
			var clippedVertices:Array<Float> = clipper.getClippedVertices();
			var clippedTriangles:Array<Int> = clipper.getClippedTriangles();
			vertices = [];
			uvs = [];
			var index:Int = 0;
			while (index < clippedVertices.length) {
				vertices.push(clippedVertices[index]);
				vertices.push(clippedVertices[index + 1]);
				uvs.push(clippedVertices[index + 4]);
				uvs.push(clippedVertices[index + 5]);
				index += 6;
			}
			// 裁剪器会在下一个插槽清空数组，提交给 Graphics 前必须复制索引。
			triangles = clippedTriangles.copy();
			#end
		}
		if (vertices.length == 0 || triangles.length == 0)
			return false;
		var texture:BitmapData = #if spine_haxe cast atlasRegion.texture #else cast atlasRegion.rendererObject #end;
		if (texture == null)
			return false;
		var color:ColorTransform = pool.get();
		__drawColors.push(color);
		color.redMultiplier = skeleton.color.r * slot.color.r * attachmentColor.r;
		color.greenMultiplier = skeleton.color.g * slot.color.g * attachmentColor.g;
		color.blueMultiplier = skeleton.color.b * slot.color.b * attachmentColor.b;
		var alpha:Float = skeleton.color.a * slot.color.a * attachmentColor.a;
		var additive:Bool = slot.data.blendMode == spine.BlendMode.additive;
		if (__spineDrawOrder != null) {
			__spineDrawOrder.onDrawOrder(slot, texture, vertices, triangles, uvs, alpha, color, additive, isStart);
		} else {
			this.beginBitmapData(texture);
			this.drawTriangles(vertices, triangles, uvs, alpha, color, additive);
		}
		return true;
	}

	private var __playing:Bool = false;

	/**
	 * 播放动画
	 * @param name 
	 * @param index 
	 * @param isLoop 
	 */
	public function play(name:String, index:Int = 0, isLoop:Bool = true):TrackEntry {
		var current:TrackEntry = this.animationState.getCurrent(index);
		if (current != null && current.animation.name == name && current.loop == isLoop
			&& (isLoop || current.trackTime < current.animationEnd - current.animationStart))
			return current;
		var entry:TrackEntry = this.animationState.setAnimationByName(index, name, isLoop);
		__playing = true;
		__spineDrawDirty = true;
		// 设置动画后再绘制，首帧即可显示目标动作；错误交由调用方处理。
		this.onUpdate(0);
		return entry;
	}

	public function stop():Void {
		this.animationState.clearTracks();
		__playing = false;
		__spineDrawDirty = true;
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
	/** 销毁时移除运行时监听，释放内部绘制数据。 */
	override public function dispose():Void {
		if (isDisposed)
			return;
		updateEnabled = false;
		#if spine_hx
		animationState.removeListener(__listener);
		__listener = null;
		#else
		animationState.onComplete.remove(onComplete);
		animationState.onEvent.remove(onEvent);
		animationState.onStart.remove(onStart);
		animationState.onEnd.remove(onEnd);
		animationState.onDispose.remove(onDispose);
		animationState.onInterrupt.remove(onInterrupt);
		#end
		animationState.clearTracks();
		clipper.clipEnd();
		clearDrawData();
		__spineDrawOrder = null;
		super.dispose();
	}
}

#if spine_hx
/** 将 3.8 的监听接口转换为引擎已有的事件接口。 */
@:access(hx.display.Spine)
private class Spine38Listener implements spine.AnimationState.AnimationStateListener {
	private var owner:Spine;

	public function new(owner:Spine) {
		this.owner = owner;
	}

	public function start(entry:TrackEntry):Void owner.onStart(entry);
	public function interrupt(entry:TrackEntry):Void owner.onInterrupt(entry);
	public function end(entry:TrackEntry):Void owner.onEnd(entry);
	public function dispose(entry:TrackEntry):Void owner.onDispose(entry);
	public function complete(entry:TrackEntry):Void owner.onComplete(entry);
	public function event(entry:TrackEntry, event:spine.Event):Void owner.onEvent(entry, event);
}
#end
#end
