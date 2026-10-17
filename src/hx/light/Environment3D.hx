package hx.light;

import hx.display.BitmapData;
import hx.render3d.Math3D;

/** 离线预积分的远距离环境光；图集包含 GGX 反射层、漫反射 E/π 和 BRDF 查找表。 */
class Environment3D {
	private static var nextId:Int = 0;
	private var id:Int = ++nextId;
	/** 借用的整图，必须保持不透明且禁止作为 sRGB 图片重新编码。 */
	public var atlas(default, null):BitmapData;
	/** 每个环境层的有效宽高，不包含一像素接缝边框。 */
	public var layerWidth(default, null):Int;
	public var layerHeight(default, null):Int;
	/** 镜面反射层数，按感知粗糙度从 0 到 1 等距排列。 */
	public var levels(default, null):Int;
	/** 图集 RGB 存储线性辐射值除以该倍率；查找表不使用此倍率。 */
	public var radianceRange(default, null):Float;
	public var enabled:Bool = true;
	/** 非负环境光强度，不影响直接光和旧 ambientIntensity。 */
	public var intensity:Float = 1;
	/** 环境绕世界 Y 轴旋转的角度，单位为度；不移动模型、灯光或背景。 */
	public var rotation:Float = 0;
	public var version(default, null):Int = 0;
	public var isDisposed(default, null):Bool = false;

	/** 借用已经加载的预处理图集，不在运行时计算卷积，也不接管图片生命周期。 */
	public function new(atlas:BitmapData, layerWidth:Int, layerHeight:Int, levels:Int, radianceRange:Float) {
		if (layerWidth < 8 || layerWidth > 1024 || layerHeight * 2 != layerWidth || levels < 2 || levels > 10
			|| !Math3D.finite(radianceRange) || radianceRange <= 0)
			throw "IBL 图集布局或辐射范围无效";
		this.atlas = atlas;
		this.layerWidth = layerWidth;
		this.layerHeight = layerHeight;
		this.levels = levels;
		this.radianceRange = radianceRange;
		settingsKey();
	}

	/** 与 tools/bake-ibl.py 生成的 JSON 配套使用；不接受普通全景图直接冒充预积分图集。 */
	public static function fromData(atlas:BitmapData, metadata:Dynamic):Environment3D {
		if (metadata == null || Reflect.field(metadata, "format") != "hxmaker-ibl-1"
			|| Reflect.field(metadata, "encoding") != "linear-rgb-range")
			throw "IBL 元数据格式或版本不支持";
		return new Environment3D(atlas, integer(metadata, "layerWidth"), integer(metadata, "layerHeight"),
			integer(metadata, "levels"), number(metadata, "radianceRange"));
	}

	/** 图片内容由业务更新后调用，同时显式通知场景 requestRender 可立即刷新。 */
	public function invalidate():Void {
		if (isDisposed) throw "环境光已经销毁";
		version++;
	}

	/** 场景按此键检测切换、旋转、强度及资源变化；关闭时仍校验资源有效性。 */
	public function settingsKey():String {
		if (isDisposed || atlas == null || atlas.data == null) throw "IBL 图集已经释放";
		if (atlas.rect != null || atlas.frameRect != null || atlas.width != layerWidth + 2
			|| atlas.height != (layerHeight + 2) * (levels + 1) + layerWidth + 2)
			throw "IBL 图集尺寸与元数据不一致，必须使用完整预积分图集";
		if (!Math3D.finite(intensity) || intensity < 0 || !Math3D.finite(rotation))
			throw "IBL 强度必须为非负有限值，旋转必须为有限角度";
		return id + ":" + version + ":" + enabled + ":" + intensity + ":" + rotation;
	}

	/** 解除借用引用；多个场景共享时，应先从所有场景移除，再销毁。 */
	public function dispose():Void {
		if (isDisposed) return;
		isDisposed = true;
		atlas = null;
	}

	private static function number(data:Dynamic, name:String):Float {
		var value:Dynamic = Reflect.field(data, name);
		if ((!Std.isOfType(value, Int) && !Std.isOfType(value, Float)) || !Math3D.finite(value))
			throw "IBL 元数据数值无效：" + name;
		return value;
	}
	private static function integer(data:Dynamic, name:String):Int {
		var value = number(data, name);
		if (value < 0 || value > 4096 || value != Math.floor(value)) throw "IBL 元数据整数无效：" + name;
		return Std.int(value);
	}
}
