package hx.render3d;

import hx.display.BitmapData;
import hx.light.Environment3D;

/** 可共享的天空图片描述；只借用整图，不接管图片生命周期。 */
class SkyboxTexture3D {
	private static var nextId:Int = 0;
	private var id:Int = ++nextId;
	public var bitmap(default, null):BitmapData;
	public var width(default, null):Int;
	public var height(default, null):Int;
	/** 有效全景区域左上角，以逻辑像素为单位。 */
	public var offset(default, null):Int;
	public var linear(default, null):Bool;
	public var radianceRange(default, null):Float;
	public var version(default, null):Int = 0;
	public var isDisposed(default, null):Bool = false;
	private var imageWidth:Int;
	private var imageHeight:Int;

	private function new(bitmap:BitmapData, width:Int, height:Int, imageWidth:Int, imageHeight:Int, range:Float, offset:Int) {
		this.bitmap = bitmap; this.width = width; this.height = height;
		this.imageWidth = imageWidth; this.imageHeight = imageHeight;
		this.offset = offset; this.linear = offset > 0; this.radianceRange = range;
		settingsKey();
	}

	/** 普通 2:1 sRGB 全景整图；接缝由后端进行周期双线性采样。 */
	public static function fromPanorama(bitmap:BitmapData):SkyboxTexture3D {
		if (bitmap == null || bitmap.data == null) throw "天空图片不能为空或已释放";
		var width = Std.int(bitmap.width), height = Std.int(bitmap.height);
		return new SkyboxTexture3D(bitmap, width, height, width, height, 1, 0);
	}

	/** 读取 bake-ibl.py 输出的带接缝边框的高清线性天空。 */
	public static function fromData(bitmap:BitmapData, metadata:Dynamic):SkyboxTexture3D {
		if (metadata == null || Reflect.field(metadata, "format") != "hxmaker-sky-1"
			|| Reflect.field(metadata, "encoding") != "linear-rgb-range") throw "天空元数据格式或编码不支持";
		var width = integer(metadata, "width"), height = integer(metadata, "height");
		var range = number(metadata, "radianceRange");
		return create(bitmap, width, height, width + 2, height + 2, range);
	}

	/** 复用旧 IBL 图集第零层，仅适合作为低分辨率背景。 */
	public static function fromEnvironment(environment:Environment3D):SkyboxTexture3D {
		if (environment == null) throw "环境不能为空";
		environment.settingsKey();
		return create(environment.atlas, environment.layerWidth, environment.layerHeight,
			Std.int(environment.atlas.width), Std.int(environment.atlas.height), environment.radianceRange);
	}

	private static function create(bitmap:BitmapData, width:Int, height:Int, imageWidth:Int, imageHeight:Int, range:Float):SkyboxTexture3D {
		return new SkyboxTexture3D(bitmap, width, height, imageWidth, imageHeight, range, 1);
	}

	public function invalidate():Void {
		settingsKey(); version++;
	}

	public function settingsKey():String {
		if (isDisposed || bitmap == null || bitmap.data == null) throw "天空图片已经释放";
		if (width < 2 || height < 1 || width != height * 2 || width > 16384
			|| bitmap.rect != null || bitmap.frameRect != null || bitmap.width != imageWidth || bitmap.height != imageHeight
			|| !Math3D.finite(radianceRange) || radianceRange <= 0 || radianceRange > 1e30) throw "天空图片尺寸、布局或辐射范围无效";
		return id + ":" + version;
	}

	/** 先从所有使用者解除引用；不释放借用图片。 */
	public function dispose():Void {
		if (isDisposed) return;
		isDisposed = true; bitmap = null;
	}

	private static function number(data:Dynamic, name:String):Float {
		var value:Dynamic = Reflect.field(data, name);
		if ((!Std.isOfType(value, Int) && !Std.isOfType(value, Float)) || !Math3D.finite(value)) throw "天空元数据数值无效：" + name;
		return value;
	}
	private static function integer(data:Dynamic, name:String):Int {
		var value = number(data, name);
		if (value < 1 || value > 16384 || value != Math.floor(value)) throw "天空元数据尺寸无效：" + name;
		return Std.int(value);
	}
}
