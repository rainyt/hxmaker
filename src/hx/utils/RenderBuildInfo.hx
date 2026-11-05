package hx.utils;

/** 构建工具传入的源码指纹；与随包清单及 source map 共同定位版本。 */
class RenderBuildInfo {
	public static var buildId(default, null):String = hx.macro.RenderBuildMacro.buildId();
}
