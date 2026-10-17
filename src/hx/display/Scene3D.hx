package hx.display;

import hx.display3d.Node3D;
import hx.display3d.Camera3D;
import hx.display3d.MeshObject;
import hx.events.Event;
import hx.events.PickResult3D;
import hx.geom.Point;
import hx.geom.Ray3D;
import hx.render3d.Scene3DStats;
import hx.render3d.BloomSettings3D;
import hx.render3d.Math3D;
import hx.render3d.Raycaster3D;
import hx.render3d.IScene3DRenderer;
import hx.core.Hxmaker;
import hx.light.DirectionalLight3D;

/** 二维显示树中的三维视口；三维对象通过 root 加入。 */
@:access(hx.display.DisplayObject)
class Scene3D extends DisplayObject {
	/** 视口销毁前派发的事件，用于输入适配与后端资源解绑。 */
	public static inline var DISPOSE:String = "scene3DDispose";

	/** 视口拥有的三维根节点；通过它加入网格、相机和灯光。 */
	public var root(default, null):Node3D;

	/** 当前活动相机，必须已加入本场景；null 表示没有可绘制相机。 */
	public var camera(get, set):Camera3D;

	/** 当前单方向光，必须属于本场景；null 时只保留环境光。 */
	public var light(get, set):DirectionalLight3D;

	/** 环境光 RGB 颜色，默认白色。 */
	public var ambientColor:Int = 0xffffff;

	/** 环境光非负有限强度，默认 0.25。 */
	public var ambientIntensity:Float = 0.25;

	private var __light:DirectionalLight3D;

	private function get_light():DirectionalLight3D {
		return __light;
	}

	private function set_light(value:DirectionalLight3D):DirectionalLight3D {
		if (value != null && (value.scene != this || value.isDisposed))
			throw "方向光必须属于当前场景";
		if (__light != value) {
			__light = value;
			requestRender();
		}
		return value;
	}

	/** 校验光照设置并返回状态键，供按需重绘检测使用。 */
	public function lightingKey():String {
		if (!Math3D.finite(ambientIntensity) || ambientIntensity < 0)
			throw "环境光强度必须为非负有限值";
		return ambientColor + ":" + ambientIntensity + ":" + (light == null ? "无方向光" : light.settingsKey());
	}

	/** 后端维护的最近绘制统计；业务只读，不代表 GPU 执行耗时。 */
	public var stats(default, null):Scene3DStats = new Scene3DStats();

	/** 按需记录三维回调的 CPU 墙钟时间，普通场景默认不读取计时器。 */
	public var profilingEnabled:Bool = false;

	/** 场景级泛光参数；修改后由设置键检测重绘，默认关闭。 */
	public var bloom(default, null):BloomSettings3D = new BloomSettings3D();

	/** 是否在可见状态每次 UPDATE 请求重绘，默认 true；关闭后可显式 requestRender。 */
	public var autoRender:Bool = true;

	/** 离屏目标相对于逻辑视口的渲染比例，默认 1。 */
	public var renderScale:Float = 1;

	/** 是否允许兼容网格使用多纹理合批，默认 true。 */
	public var multiTextureEnabled:Bool = true;

	/** 离屏目标背景 RGB 颜色，默认黑色。 */
	public var backgroundColor:Int = 0;

	/** 离屏目标背景不透明度，默认 0；与二维显示透明度共同参与最终合成。 */
	public var backgroundAlpha:Float = 0;

	/** 三维内容失效版本，每次 requestRender 递增。 */
	public var contentVersion(default, null):Int = 0;

	private var __camera:Camera3D;
	private var __viewportWidth:Float = 0;
	private var __viewportHeight:Float = 0;
	private var __settings:String;

	/** 创建二维显示树中的三维视口，参数为逻辑宽高；不自动创建相机。 */
	public function new(width:Float = 640, height:Float = 360) {
		super();
		root = new Node3D();
		root.setScene(this);
		updateEnabled = true;
		setSize(width, height);
	}

	private function get_camera():Camera3D {
		return __camera;
	}

	private function set_camera(value:Camera3D):Camera3D {
		if (value != null && (value.scene != this || value.isDisposed))
			throw "活动相机必须属于当前场景";
		if (__camera != value) {
			__camera = value;
			requestRender();
		}
		return value;
	}

	/** 设置非负有限逻辑视口尺寸，更新二维边界并请求重绘。 */
	public function setSize(width:Float, height:Float):Void {
		if (!Math3D.finite(width) || !Math3D.finite(height) || width < 0 || height < 0)
			throw "三维视口尺寸无效";
		__viewportWidth = width;
		__viewportHeight = height;
		__rect.setTo(0, 0, width, height);
		requestRender();
	}

	override private function get_width():Float {
		return __viewportWidth;
	}

	override private function get_height():Float {
		return __viewportHeight;
	}

	override private function set_width(value:Float):Float {
		setSize(value, __viewportHeight);
		return value;
	}

	override private function set_height(value:Float):Float {
		setSize(__viewportWidth, value);
		return value;
	}

	/** 按可选参数调整逻辑宽高，未提供的维度保持原值。 */
	override public function resize(?width:Null<Float>, ?height:Null<Float>):Void {
		setSize(width == null ? __viewportWidth : width, height == null ? __viewportHeight : height);
	}

	/** 标记三维内容和二维合成失效，不立即绘制或推进动画。 */
	public function requestRender():Void {
		if (isDisposed)
			return;
		contentVersion++;
		setDirty();
	}

	/** 加入舞台时检查后端三维能力并请求首次绘制。 */
	override public function onAddToStage():Void {
		super.onAddToStage();
		if (Hxmaker.engine != null && !Std.isOfType(Hxmaker.engine.renderer, IScene3DRenderer))
			throw "当前 hxmaker 后端没有实现 Scene3D 绘制接口";
		requestRender();
	}

	/** 检查场景设置和自动重绘开关；不推进三维对象的业务动画。 */
	override public function onUpdate(dt:Float):Void {
		super.onUpdate(dt);
		var values:Array<Dynamic> = [
			                            renderScale,                  backgroundColor,                 backgroundAlpha, multiTextureEnabled ? 1 : 0,
			camera == null ? 0 : camera.fieldOfView, camera == null ? 0 : camera.near, camera == null ? 0 : camera.far,               lightingKey(), bloom.settingsKey()
		];
		var settings = values.join(":");
		if (settings != __settings) {
			__settings = settings;
			requestRender();
		}
		var current:DisplayObject = this;
		while (current != null && current.visible && !current.hide)
			current = current.parent;
		if (autoRender && current == null && width > 0 && height > 0)
			requestRender();
	}

	/** 舞台坐标转逻辑视口坐标；不检查二维覆盖物和祖先遮罩。 */
	public function stageToViewport(stageX:Float, stageY:Float):Point {
		if (isDisposed || stage == null || width <= 0 || height <= 0 || !Math3D.finite(stageX) || !Math3D.finite(stageY))
			return null;
		var current:DisplayObject = this;
		while (current != null) {
			if (!current.visible || current.isDisposed)
				return null;
			current = current.parent;
		}
		stage.__updateTransform(null);
		var m = __worldTransform, det = m.a * m.d - m.b * m.c;
		if (Math.abs(det) < 1e-12)
			return null;
		var dx = stageX - m.tx, dy = stageY - m.ty;
		var x = (m.d * dx - m.c * dy) / det, y = (-m.b * dx + m.a * dy) / det;
		return x < 0 || y < 0 || x > width || y > height ? null : new Point(x, y);
	}

	/** 射线起点位于相机近裁剪面，输入为 hxmaker 舞台坐标。 */
	public function stageRay(stageX:Float, stageY:Float):Ray3D {
		var point = stageToViewport(stageX, stageY);
		return point == null || camera == null ? null : camera.screenRay(point.x, point.y, width, height);
	}

	/** 世界射线查询三维节点树；不使用视口近远裁剪，不检查二维 UI。 */
	public function raycast(ray:Ray3D, maxDistance:Null<Float> = null, filter:MeshObject->Bool = null):PickResult3D {
		return isDisposed ? null : Raycaster3D.intersect(root, ray, maxDistance, filter);
	}

	/** 输入为舞台坐标，保留视口与近远裁剪；maxDistance=null 表示不限距离。 */
	public function pick(stageX:Float, stageY:Float, maxDistance:Null<Float> = null, filter:MeshObject->Bool = null):PickResult3D {
		var ray = stageRay(stageX, stageY);
		return ray == null ? null : Raycaster3D.intersect(root, ray, maxDistance, filter, camera.getViewProjection(width / height));
	}

	/** 幂等派发销毁事件、销毁根节点树并释放二维视口，不接管外部共享几何材质。 */
	override public function dispose():Void {
		if (isDisposed)
			return;
		dispatchEvent(new Event(DISPOSE));
		root.dispose();
		__camera = null;
		__light = null;
		super.dispose();
	}
}
