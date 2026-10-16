package hx.material;

import hx.display.BitmapData;
import hx.display.EventDispatcher;
import hx.events.Event;
import hx.render3d.Math3D;

/** 基础三维材质；共享修改通过 CHANGE 通知所有引用模型。 */
class Material3D extends EventDispatcher {
	public var version(default, null):Int = 0;
	public var referenceCount(default, null):Int = 0;
	public var isDisposed(default, null):Bool = false;
	/** 贴图由资产系统持有，材质不接管它的销毁。 */
	private var __texture:BitmapData = null;
	public var texture(get, set):BitmapData;
	private function get_texture():BitmapData { return __texture; }
	private function set_texture(value:BitmapData):BitmapData {

		if (__texture != value) { __texture = value; invalidate(); } return value;
	}
	private var __color:Int = 0xffffff;
	public var color(get, set):Int;
	private function get_color():Int { return __color; }
	private function set_color(value:Int):Int {

		if (__color != value) { __color = value; invalidate(); } return value;
	}
	private var __opacity:Float = 1;
	public var opacity(get, set):Float;
	private function get_opacity():Float { return __opacity; }
	private function set_opacity(value:Float):Float {
		if (!Math3D.finite(value) || value < 0 || value > 1) throw "材质透明参数必须介于 0 和 1";
		if (__opacity != value) { __opacity = value; invalidate(); } return value;
	}
	private var __alphaMode:AlphaMode3D = AlphaMode3D.OPAQUE;
	public var alphaMode(get, set):AlphaMode3D;
	private function get_alphaMode():AlphaMode3D { return __alphaMode; }
	private function set_alphaMode(value:AlphaMode3D):AlphaMode3D {

		if (__alphaMode != value) { __alphaMode = value; invalidate(); } return value;
	}
	private var __alphaCutoff:Float = 0.5;
	public var alphaCutoff(get, set):Float;
	private function get_alphaCutoff():Float { return __alphaCutoff; }
	private function set_alphaCutoff(value:Float):Float {
		if (!Math3D.finite(value) || value < 0 || value > 1) throw "材质透明参数必须介于 0 和 1";
		if (__alphaCutoff != value) { __alphaCutoff = value; invalidate(); } return value;
	}
	private var __cullMode:CullMode3D = CullMode3D.BACK;
	public var cullMode(get, set):CullMode3D;
	private function get_cullMode():CullMode3D { return __cullMode; }
	private function set_cullMode(value:CullMode3D):CullMode3D {

		if (__cullMode != value) { __cullMode = value; invalidate(); } return value;
	}
	private var __depthTest:Bool = true;
	public var depthTest(get, set):Bool;
	private function get_depthTest():Bool { return __depthTest; }
	private function set_depthTest(value:Bool):Bool {

		if (__depthTest != value) { __depthTest = value; invalidate(); } return value;
	}
	private var __depthWrite:Bool = true;
	public var depthWrite(get, set):Bool;
	private function get_depthWrite():Bool { return __depthWrite; }
	private function set_depthWrite(value:Bool):Bool {

		if (__depthWrite != value) { __depthWrite = value; invalidate(); } return value;
	}
	private var __smoothing:Bool = true;
	public var smoothing(get, set):Bool;
	private function get_smoothing():Bool { return __smoothing; }
	private function set_smoothing(value:Bool):Bool {

		if (__smoothing != value) { __smoothing = value; invalidate(); } return value;
	}
	private var __fragmentCode:String = "";
	public var fragmentCode(get, set):String;
	private function get_fragmentCode():String { return __fragmentCode; }
	private function set_fragmentCode(value:String):String {
		if (value == null) value = "";
		if (__fragmentCode != value) { __fragmentCode = value; invalidate(); } return value;
	}
	private var __uniforms:Map<String, Array<Float>> = [];
	private var __fragmentDeclarations:String = "";
	/** 片元全局声明，例如 uniform vec3 uTint；修改后生成独立程序。 */
	public var fragmentDeclarations(get, set):String;
	private function get_fragmentDeclarations():String { return __fragmentDeclarations; }
	private function set_fragmentDeclarations(value:String):String {
		if (value == null) value = "";
		if (__fragmentDeclarations != value) { __fragmentDeclarations = value; invalidate(); } return value;
	}
	public function new() {}
	/** uniform 数值复制后保存，避免后续批次覆盖前一个批次。 */
	public function setUniform(name:String, values:Array<Float>):Void {
		if (name == null || !~/^[A-Za-z_][A-Za-z0-9_]*$/.match(name) || StringTools.startsWith(name, "uSampler")
			|| ["uViewProjection", "uAlphaMode", "uAlphaCutoff"].indexOf(name) >= 0) throw "自定义 uniform 名称无效或与内置变量冲突";
		if (values == null || [1,2,3,4,16].indexOf(values.length) < 0) throw "uniform 只支持浮点标量、向量或四阶矩阵";
		for (v in values) if (!Math3D.finite(v)) throw "uniform 包含无效数值";
		__uniforms.set(name, values.copy()); invalidate();
	}
	public function getUniforms():Map<String, Array<Float>> {
		var result:Map<String, Array<Float>> = [];
		for (key => values in __uniforms) result.set(key, values.copy());
		return result;
	}
	public function uniformKey():String {
		var keys = [for (key in __uniforms.keys()) key]; keys.sort(Reflect.compare);
		return [for (key in keys) key + ":" + __uniforms.get(key).join(",")].join(";");
	}
	public function invalidate():Void {
		if (isDisposed) throw "材质已经销毁";
		version++; dispatchEvent(new Event(Event.CHANGE));
	}
	public function retain():Void { if (isDisposed) throw "材质已经销毁"; referenceCount++; }
	public function release():Void { if (referenceCount > 0) referenceCount--; }
	public function dispose():Void {
		if (referenceCount != 0) throw "仍有模型使用此材质";
		if (isDisposed) return;
		isDisposed = true; __texture = null; __uniforms.clear(); removeEventListeners();
	}
}
