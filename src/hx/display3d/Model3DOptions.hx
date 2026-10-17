package hx.display3d;

/** 实例化选项；默认继续使用无光照材质。 */
typedef Model3DOptions = {
	/** 是否为导入材质启用基础光照，省略时为 false。 */
	@:optional var lightingEnabled:Bool;
	/** 是否使用 PBR 材质，省略时为 false；true 优先于 lightingEnabled。 */
	@:optional var pbrEnabled:Bool;
}
