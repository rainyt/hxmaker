package hx.display;

import hx.events.Event;
import hx.events.PickResult3D;
import hx.geom.Point;
import hx.geom.Ray3D;
import hx.render3d.Scene3DStats;
import hx.render3d.Math3D;
import hx.render3d.Raycaster3D;
import hx.render3d.IScene3DRenderer;
import hx.core.Hxmaker;
import hx.light.DirectionalLight3D;

/** 二维显示树中的三维视口；三维对象通过 root 加入。 */
@:access(hx.display.DisplayObject)
class Scene3D extends DisplayObject {
	public static inline var DISPOSE:String = "scene3DDispose";
	public var root(default, null):Node3D;
	public var camera(get, set):Camera3D;
	public var light(get, set):DirectionalLight3D;
	public var ambientColor:Int = 0xffffff;
	public var ambientIntensity:Float = 0.25;
	private var __light:DirectionalLight3D;
	private function get_light():DirectionalLight3D { return __light; }
	private function set_light(value:DirectionalLight3D):DirectionalLight3D {
		if (value != null && (value.scene != this || value.isDisposed)) throw "方向光必须属于当前场景";
		if (__light != value) { __light = value; requestRender(); } return value;
	}
	public function lightingKey():String {
		if (!Math3D.finite(ambientIntensity) || ambientIntensity < 0) throw "环境光强度必须为非负有限值";
		return ambientColor + ":" + ambientIntensity + ":" + (light == null ? "无方向光" : light.settingsKey());
	}
	public var stats(default, null):Scene3DStats = new Scene3DStats();
	/** 按需记录三维回调的 CPU 墙钟时间，普通场景默认不读取计时器。 */
	public var profilingEnabled:Bool = false;
	public var autoRender:Bool = true;
	public var renderScale:Float = 1;
	public var multiTextureEnabled:Bool = true;
	public var backgroundColor:Int = 0;
	public var backgroundAlpha:Float = 0;
	public var contentVersion(default, null):Int = 0;
	private var __camera:Camera3D;
	private var __viewportWidth:Float = 0;
	private var __viewportHeight:Float = 0;
	private var __settings:String;
	public function new(width:Float = 640, height:Float = 360) {
		super(); root = new Node3D(); root.setScene(this); updateEnabled = true;
		setSize(width, height);
	}
	private function get_camera():Camera3D { return __camera; }
	private function set_camera(value:Camera3D):Camera3D {
		if (value != null && (value.scene != this || value.isDisposed)) throw "活动相机必须属于当前场景";
		if (__camera != value) { __camera = value; requestRender(); } return value;
	}
	public function setSize(width:Float, height:Float):Void {
		if (!Math3D.finite(width) || !Math3D.finite(height) || width < 0 || height < 0) throw "三维视口尺寸无效";
		__viewportWidth = width; __viewportHeight = height;
		__rect.setTo(0, 0, width, height); requestRender();
	}
	override private function get_width():Float { return __viewportWidth; }
	override private function get_height():Float { return __viewportHeight; }
	override private function set_width(value:Float):Float { setSize(value, __viewportHeight); return value; }
	override private function set_height(value:Float):Float { setSize(__viewportWidth, value); return value; }
	override public function resize(?width:Null<Float>, ?height:Null<Float>):Void {
		setSize(width == null ? __viewportWidth : width, height == null ? __viewportHeight : height);
	}
	public function requestRender():Void {
		if (isDisposed) return;
		contentVersion++; setDirty();
	}
	override public function onAddToStage():Void {
		super.onAddToStage();
		if (Hxmaker.engine != null && !Std.isOfType(Hxmaker.engine.renderer, IScene3DRenderer))
			throw "当前 hxmaker 后端没有实现 Scene3D 绘制接口";
		requestRender();
	}
	override public function onUpdate(dt:Float):Void {
		super.onUpdate(dt);
		var values:Array<Dynamic> = [renderScale, backgroundColor, backgroundAlpha, multiTextureEnabled ? 1 : 0,
			camera == null ? 0 : camera.fieldOfView, camera == null ? 0 : camera.near, camera == null ? 0 : camera.far, lightingKey()];
		var settings = values.join(":");
		if (settings != __settings) { __settings = settings; requestRender(); }
		var current:DisplayObject = this;
		while (current != null && current.visible && !current.hide) current = current.parent;
		if (autoRender && current == null && width > 0 && height > 0) requestRender();
	}
	/** 舞台坐标转逻辑视口坐标；不检查二维覆盖物和祖先遮罩。 */
	public function stageToViewport(stageX:Float, stageY:Float):Point {
		if (isDisposed || stage == null || width <= 0 || height <= 0 || !Math3D.finite(stageX) || !Math3D.finite(stageY)) return null;
		var current:DisplayObject = this;
		while (current != null) { if (!current.visible || current.isDisposed) return null; current = current.parent; }
		stage.__updateTransform(null);
		var m = __worldTransform, det = m.a * m.d - m.b * m.c;
		if (Math.abs(det) < 1e-12) return null;
		var dx = stageX - m.tx, dy = stageY - m.ty;
		var x = (m.d * dx - m.c * dy) / det, y = (-m.b * dx + m.a * dy) / det;
		return x < 0 || y < 0 || x > width || y > height ? null : new Point(x,y);
	}
	/** 射线起点位于相机近裁剪面，输入为 hxmaker 舞台坐标。 */
	public function stageRay(stageX:Float, stageY:Float):Ray3D {
		var point = stageToViewport(stageX,stageY);
		return point == null || camera == null ? null : camera.screenRay(point.x,point.y,width,height);
	}
	/** 世界射线查询三维节点树；不使用视口近远裁剪，不检查二维 UI。 */
	public function raycast(ray:Ray3D, maxDistance:Null<Float> = null, filter:MeshObject->Bool = null):PickResult3D {
		return isDisposed ? null : Raycaster3D.intersect(root,ray,maxDistance,filter);
	}
	/** 输入为舞台坐标，保留视口与近远裁剪；maxDistance=null 表示不限距离。 */
	public function pick(stageX:Float, stageY:Float, maxDistance:Null<Float> = null, filter:MeshObject->Bool = null):PickResult3D {
		var ray = stageRay(stageX,stageY);
		return ray == null ? null : Raycaster3D.intersect(root,ray,maxDistance,filter,camera.getViewProjection(width/height));
	}
	override public function dispose():Void {
		if (isDisposed) return;
		dispatchEvent(new Event(DISPOSE)); root.dispose(); __camera = null; __light = null; super.dispose();
	}
}
