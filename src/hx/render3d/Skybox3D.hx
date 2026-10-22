package hx.render3d;

/** 每个场景独立的天空显示参数，图片资源可以跨场景共享。 */
class Skybox3D {
	public var texture:SkyboxTexture3D;
	public var enabled:Bool = true;
	/** 与 Environment3D 相同的世界 Y 轴采样旋转角，单位为度。 */
	public var rotation:Float = 0;
	public var intensity:Float = 1;
	/** 在线性空间进行色调映射前的非负亮度倍率。 */
	public var exposure:Float = 1;
	/** 默认关闭，普通 sRGB 图片保持原貌；HDR 资源通常应开启。 */
	public var toneMapping:Bool = false;
	public var isDisposed(default, null):Bool = false;

	public function new(texture:SkyboxTexture3D) {
		this.texture = texture; settingsKey();
	}
	public function settingsKey():String {
		if (isDisposed || texture == null) throw "天空配置已经释放或缺少资源";
		if (!Math3D.finite(rotation) || !Math3D.finite(intensity) || intensity < 0
			|| intensity > 1e6 || !Math3D.finite(exposure) || exposure < 0 || exposure > 1e6) throw "天空旋转、强度或曝光无效";
		if (intensity * exposure * texture.radianceRange > 1e30) throw "天空辐射与曝光乘积超出支持范围";
		return texture.settingsKey() + ":" + enabled + ":" + rotation + ":" + intensity + ":" + exposure + ":" + toneMapping;
	}
	/** 不销毁共享天空资源。 */
	public function dispose():Void { isDisposed = true; texture = null; }
}
