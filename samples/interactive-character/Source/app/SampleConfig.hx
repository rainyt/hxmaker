package app;

import hx.render3d.Math3D;

/** 示例配置保持代码形式，暂不冻结场景序列化格式。 */
class SampleConfig {
	public var assetPath:String = "assets/robot.glb";
	public var assetName:String = "robot";
	public var characterCount:Int = 3;
	public var movementSpeed:Float = 1.8;
	public var fadeSeconds:Float = 0.2;
	/** 保留短暂加载界面，便于用户操作取消，不限制引擎帧率。 */
	public var minimumLoadingSeconds:Float = 0.6;
	public function new() {}
	public function validate():Void {
		if (assetPath == null || assetPath.length == 0 || assetName == null || assetName.length == 0 || characterCount < 1) throw "示例资源或角色数量配置无效";
		for (value in [movementSpeed,fadeSeconds,minimumLoadingSeconds]) if (!Math3D.finite(value)) throw "示例时间与速度必须是有限数值";
		if (movementSpeed <= 0 || fadeSeconds < 0 || minimumLoadingSeconds < 0) throw "示例速度或时间范围无效";
	}
}
