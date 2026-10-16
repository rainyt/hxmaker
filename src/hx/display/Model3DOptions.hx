package hx.display;

/** 实例化选项；默认继续使用无光照材质。 */
typedef Model3DOptions = {
	/** 是否为导入材质启用基础光照，省略时为 false。 */
	@:optional var lightingEnabled:Bool;
}
