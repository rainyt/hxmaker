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
import hx.light.Light3D;
import hx.light.Environment3D;

/** 二维显示树中的三维视口；三维对象通过 root 加入。 */
@:access(hx.display.DisplayObject)
class Scene3D extends DisplayObject {
	/** 视口销毁前派发的事件，用于输入适配与后端资源解绑。 */
	public static inline var DISPOSE:String = "scene3DDispose";

	/** 视口拥有的三维根节点；通过它加入网格、相机和灯光。 */
	public var root(default, null):Node3D;

	/** 当前活动相机，必须已加入本场景；null 表示没有可绘制相机。 */
	public var camera(get, set):Camera3D;

	/** 主方向光兼容入口，必须属于本场景；null 时仍可使用显式注册的其他灯光。 */
	public var light(get, set):DirectionalLight3D;

	/** 首版前向光照上限，包含兼容入口 light。 */
	public static inline var MAX_LIGHTS:Int = 4;
	private var __lights:Array<Light3D> = [];
	/** 显式注册的灯光副本；不包含仅通过 light 设置的主方向光。 */
	public var lights(get, never):Array<Light3D>;
	private function get_lights():Array<Light3D> { return __lights.copy(); }

	/** 灯光需先加入 root；重复注册不改变顺序。 */
	public function addLight(value:Light3D):Void {
		if (value == null || value.isDisposed || value.scene != this)
			throw "灯光必须属于当前场景";
		if (__lights.indexOf(value) < 0) { __lights.push(value); requestRender(); }
	}

	/** 取消显式注册；主方向光需另外设置 light=null。 */
	public function removeLight(value:Light3D):Void {
		if (__lights.remove(value)) requestRender();
	}

	/** 主方向光优先，其余按注册顺序；隐藏、移出场景或销毁的灯光不参与。 */
	public function getActiveLights():Array<Light3D> {
		var result:Array<Light3D> = [];
		var candidates = __lights.copy();
		if (light != null) { candidates.remove(light); candidates.unshift(light); }
		for (value in candidates) {
			if (value.isDisposed || value.scene != this || !value.isWorldVisible()) continue;
			value.settingsKey();
			if (value.intensity > 0) result.push(value);
		}
		return result;
	}

	/** 环境光 RGB 颜色，默认白色。 */
	public var ambientColor:Int = 0xffffff;

	/** 环境光非负有限强度，默认 0.25。 */
	public var ambientIntensity:Float = 0.25;

	/** 可选的借用 IBL 环境，仅作用于启用光照的 PBR 材质；场景不接管其销毁。 */
	public var environment:Environment3D;

	/** 可选的天空背景；借用配置和纹理，不参与节点树、拾取或阴影。 */
	public var skybox:hx.render3d.Skybox3D;

	public function skyboxKey():String {
		return skybox == null ? "" : skybox.settingsKey();
	}

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
		var keys = [for (value in getActiveLights()) value.settingsKey()];
		return ambientColor + ":" + ambientIntensity + ":" + keys.join("|") + ":"
			+ (environment == null ? "" : environment.settingsKey());
	}

	/** 后端维护的最近绘制统计；业务只读，不代表 GPU 执行耗时。 */
	public var stats(default, null):Scene3DStats = new Scene3DStats();

	/** 按需记录三维回调的 CPU 墙钟时间，普通场景默认不读取计时器。 */
	public var profilingEnabled:Bool = false;

	/** 场景级泛光参数；修改后由设置键检测重绘，默认关闭。 */
	public var bloom(default, null):BloomSettings3D = new BloomSettings3D();

	/** 场景级距离雾；默认关闭，配置可由 Blender 导出的场景数据加载。 */
	public var fog(default, null):hx.render3d.FogSettings3D = new hx.render3d.FogSettings3D();

	/** 是否在可见状态每次 UPDATE 请求重绘，默认 true；关闭后可显式 requestRender。 */
	public var autoRender:Bool = true;
	/** 主场景几何缓存开关，可关闭以便比较原绘制路径。 */
	public var geometryCacheEnabled:Bool = true;
	private var __autoStaticDelay:Float = 1;
	private var mobilityTracker:hx.render3d.MobilityTracker3D = new hx.render3d.MobilityTracker3D();
	/** AUTO 转静态前需要持续静止的秒数。 */
	public var autoStaticDelay(get, set):Float;
	private function get_autoStaticDelay():Float { return __autoStaticDelay; }
	private function set_autoStaticDelay(value:Float):Float {
		if (!Math3D.finite(value) || value < 0) throw "自动静态等待时间无效";
		if (__autoStaticDelay != value) { __autoStaticDelay = value; requestRender(); }
		return value;
	}
	/** 更新周期与绘制前都可同步，材质和相机变化不会被误判成物体运动。 */
	public function updateMobility():Void { if (!isDisposed) mobilityTracker.update(this); }

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
		mobilityTracker.advance();
		updateMobility();
		var values:Array<Dynamic> = [
			                            geometryCacheEnabled ? 1 : 0, renderScale,                  backgroundColor,                 backgroundAlpha, multiTextureEnabled ? 1 : 0,
			camera == null ? 0 : camera.fieldOfView, camera == null ? 0 : camera.near, camera == null ? 0 : camera.far,               lightingKey(), bloom.settingsKey()
		];
		var settings = values.join(":") + ":sky:" + skyboxKey() + ":fog:" + fog.settingsKey();
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
		mobilityTracker.clear();
		root.dispose();
		__camera = null;
		__light = null;
		__lights = [];
		environment = null;
		skybox = null;
		super.dispose();
	}
}
