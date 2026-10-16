package hx.material;

import hx.display.BitmapData;
import hx.display.EventDispatcher;
import hx.events.Event;
import hx.render3d.Math3D;

/** 基础三维材质；共享修改通过 CHANGE 通知所有引用模型。 */
class Material3D extends EventDispatcher {
	private var __colorMultiplyLinear:Bool = false;

	/** glTF 的基础颜色因子需在线性空间与贴图相乘；旧手工材质默认保持显示空间行为。 */
	public var colorMultiplyLinear(get, set):Bool;

	private function get_colorMultiplyLinear():Bool {
		return __colorMultiplyLinear;
	}

	private function set_colorMultiplyLinear(value:Bool):Bool {
		if (__colorMultiplyLinear != value) {
			__colorMultiplyLinear = value;
			invalidate();
		}
		return value;
	}

	private var __lightingEnabled:Bool = false;

	/** 是否参与环境光、方向光及接收阴影；默认 false。 */
	public var lightingEnabled(get, set):Bool;

	private function get_lightingEnabled():Bool {
		return __lightingEnabled;
	}

	private function set_lightingEnabled(value:Bool):Bool {
		if (__lightingEnabled != value) {
			__lightingEnabled = value;
			invalidate();
		}
		return value;
	}

	/** 数据变更版本，用于使渲染缓存失效。 */
	public var version(default, null):Int = 0;

	/** 当前网格持有的引用数量；释放到零后仍需显式销毁资源。 */
	public var referenceCount(default, null):Int = 0;

	/** 是否已经销毁；销毁后不得继续修改或更新。 */
	public var isDisposed(default, null):Bool = false;

	/** 贴图由资产系统持有，材质不接管它的销毁。 */
	private var __texture:BitmapData = null;

	/** 借用的 hxmaker 位图；材质不接管资产系统贴图的销毁。 */
	public var texture(get, set):BitmapData;

	private function get_texture():BitmapData {
		return __texture;
	}

	private function set_texture(value:BitmapData):BitmapData {
		if (__texture != value) {
			__texture = value;
			invalidate();
		}
		return value;
	}

	private var __color:Int = 0xffffff;

	/** RGB 基础颜色，默认白色，与纹理颜色相乘。 */
	public var color(get, set):Int;

	private function get_color():Int {
		return __color;
	}

	private function set_color(value:Int):Int {
		if (__color != value) {
			__color = value;
			invalidate();
		}
		return value;
	}

	private var __opacity:Float = 1;

	/** 整体不透明度，范围 0 至 1，默认 1。 */
	public var opacity(get, set):Float;

	private function get_opacity():Float {
		return __opacity;
	}

	private function set_opacity(value:Float):Float {
		if (!Math3D.finite(value) || value < 0 || value > 1)
			throw "材质透明参数必须介于 0 和 1";
		if (__opacity != value) {
			__opacity = value;
			invalidate();
		}
		return value;
	}

	private var __alphaMode:AlphaMode3D = AlphaMode3D.OPAQUE;

	/** 透明处理模式，默认 OPAQUE；不同模式影响绘制排序和合批。 */
	public var alphaMode(get, set):AlphaMode3D;

	private function get_alphaMode():AlphaMode3D {
		return __alphaMode;
	}

	private function set_alphaMode(value:AlphaMode3D):AlphaMode3D {
		if (__alphaMode != value) {
			__alphaMode = value;
			invalidate();
		}
		return value;
	}

	private var __alphaCutoff:Float = 0.5;

	/** MASK 模式的透明裁剪阈值，范围 0 至 1，默认 0.5。 */
	public var alphaCutoff(get, set):Float;

	private function get_alphaCutoff():Float {
		return __alphaCutoff;
	}

	private function set_alphaCutoff(value:Float):Float {
		if (!Math3D.finite(value) || value < 0 || value > 1)
			throw "材质透明参数必须介于 0 和 1";
		if (__alphaCutoff != value) {
			__alphaCutoff = value;
			invalidate();
		}
		return value;
	}

	private var __cullMode:CullMode3D = CullMode3D.BACK;

	/** 面剔除方式，默认剔除背面；镜像节点由渲染器处理绕序。 */
	public var cullMode(get, set):CullMode3D;

	private function get_cullMode():CullMode3D {
		return __cullMode;
	}

	private function set_cullMode(value:CullMode3D):CullMode3D {
		if (__cullMode != value) {
			__cullMode = value;
			invalidate();
		}
		return value;
	}

	private var __depthTest:Bool = true;

	/** 是否进行深度测试，默认 true。 */
	public var depthTest(get, set):Bool;

	private function get_depthTest():Bool {
		return __depthTest;
	}

	private function set_depthTest(value:Bool):Bool {
		if (__depthTest != value) {
			__depthTest = value;
			invalidate();
		}
		return value;
	}

	private var __depthWrite:Bool = true;

	/** 是否写入深度，默认 true；透明混合仍受渲染通道规则约束。 */
	public var depthWrite(get, set):Bool;

	private function get_depthWrite():Bool {
		return __depthWrite;
	}

	private function set_depthWrite(value:Bool):Bool {
		if (__depthWrite != value) {
			__depthWrite = value;
			invalidate();
		}
		return value;
	}

	private var __smoothing:Bool = true;
	private var __textureMinSmoothing:Null<Bool> = null;

	/** null 表示缩小时沿用 smoothing；GLB 可分别指定缩小与放大过滤。 */
	public var textureMinSmoothing(get, set):Null<Bool>;

	private function get_textureMinSmoothing():Null<Bool> {
		return __textureMinSmoothing;
	}

	private function set_textureMinSmoothing(value:Null<Bool>):Null<Bool> {
		if (__textureMinSmoothing != value) {
			__textureMinSmoothing = value;
			invalidate();
		}
		return value;
	}

	private var __textureWrapU:TextureWrap3D = TextureWrap3D.CLAMP;
	private var __textureWrapV:TextureWrap3D = TextureWrap3D.CLAMP;

	/** U 方向包裹模式，默认 CLAMP；重复模式受纹理尺寸与后端能力约束。 */
	public var textureWrapU(get, set):TextureWrap3D;

	/** V 方向包裹模式，默认 CLAMP；重复模式受纹理尺寸与后端能力约束。 */
	public var textureWrapV(get, set):TextureWrap3D;

	private function get_textureWrapU():TextureWrap3D {
		return __textureWrapU;
	}

	private function get_textureWrapV():TextureWrap3D {
		return __textureWrapV;
	}

	private function set_textureWrapU(value:TextureWrap3D):TextureWrap3D {
		validateWrap(value);
		if (__textureWrapU != value) {
			__textureWrapU = value;
			invalidate();
		}
		return value;
	}

	private function set_textureWrapV(value:TextureWrap3D):TextureWrap3D {
		validateWrap(value);
		if (__textureWrapV != value) {
			__textureWrapV = value;
			invalidate();
		}
		return value;
	}

	private static function validateWrap(value:Int):Void {
		if ([33071, 10497, 33648].indexOf(value) < 0)
			throw "纹理包裹模式无效";
	}

	/** 放大时是否线性过滤；textureMinSmoothing 为 null 时也控制缩小过滤。 */
	public var smoothing(get, set):Bool;

	private function get_smoothing():Bool {
		return __smoothing;
	}

	private function set_smoothing(value:Bool):Bool {
		if (__smoothing != value) {
			__smoothing = value;
			invalidate();
		}
		return value;
	}

	private var __fragmentCode:String = "";

	/** 在基础纹理取样之后执行的 GLSL 片元代码，修改会改变程序兼容性。 */
	public var fragmentCode(get, set):String;

	private function get_fragmentCode():String {
		return __fragmentCode;
	}

	private function set_fragmentCode(value:String):String {
		if (value == null)
			value = "";
		if (__fragmentCode != value) {
			__fragmentCode = value;
			invalidate();
		}
		return value;
	}

	private var __uniforms:Map<String, Array<Float>> = [];
	private var __fragmentDeclarations:String = "";

	/** 片元全局声明，例如 uniform vec3 uTint；修改后生成独立程序。 */
	public var fragmentDeclarations(get, set):String;

	private function get_fragmentDeclarations():String {
		return __fragmentDeclarations;
	}

	private function set_fragmentDeclarations(value:String):String {
		if (value == null)
			value = "";
		if (__fragmentDeclarations != value) {
			__fragmentDeclarations = value;
			invalidate();
		}
		return value;
	}

	/** 创建无贴图基础材质，默认无光照、不透明且启用深度。 */
	public function new() {}

	/** uniform 数值复制后保存，避免后续批次覆盖前一个批次。 */
	public function setUniform(name:String, values:Array<Float>):Void {
		if (name == null
			|| !~/^[A-Za-z_][A-Za-z0-9_]*$/.match(name)
			|| StringTools.startsWith(name, "uSampler")
			|| [
				"uViewProjection",
				"uAlphaMode",
				"uAlphaCutoff",
				"uLinearBaseColor",
				"uAmbientColor",
				"uLightColor",
				"uLightDirection",
				"uLightViewProjection",
				"uShadowMap",
				"uReceiveShadow",
				"uShadowBias",
				"uShadowSlopeBias"
			].indexOf(name) >= 0)
			throw "自定义 uniform 名称无效或与内置变量冲突";
		if (values == null || [1, 2, 3, 4, 16].indexOf(values.length) < 0)
			throw "uniform 只支持浮点标量、向量或四阶矩阵";
		for (v in values)
			if (!Math3D.finite(v))
				throw "uniform 包含无效数值";
		__uniforms.set(name, values.copy());
		invalidate();
	}

	/** 返回自定义 uniform 名称与数值数组的深拷贝。 */
	public function getUniforms():Map<String, Array<Float>> {
		var result:Map<String, Array<Float>> = [];
		for (key => values in __uniforms)
			result.set(key, values.copy());
		return result;
	}

	/** 返回按名称稳定排序的 uniform 数值键，供渲染批次兼容判断。 */
	public function uniformKey():String {
		var keys = [for (key in __uniforms.keys()) key];
		keys.sort(Reflect.compare);
		return [for (key in keys) key + ":" + __uniforms.get(key).join(",")].join(";");
	}

	/** 递增材质版本并派发 CHANGE，通知所有引用网格重新绘制。 */
	public function invalidate():Void {
		if (isDisposed)
			throw "材质已经销毁";
		version++;
		dispatchEvent(new Event(Event.CHANGE));
	}

	/** 增加网格引用；已销毁资源不能再次引用。 */
	public function retain():Void {
		if (isDisposed)
			throw "材质已经销毁";
		referenceCount++;
	}

	/** 减少网格引用，计数不会小于零；不自动销毁资源。 */
	public function release():Void {
		if (referenceCount > 0)
			referenceCount--;
	}

	/** 无网格引用时幂等释放材质状态，不销毁借用贴图；仍被引用时抛异常。 */
	public function dispose():Void {
		if (referenceCount != 0)
			throw "仍有模型使用此材质";
		if (isDisposed)
			return;
		isDisposed = true;
		__texture = null;
		__uniforms.clear();
		removeEventListeners();
	}
}
