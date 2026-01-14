package hx.particle;

/**
 * 通用粒子数据格式
 */
typedef JSONParticleData = {
	/** 粒子初始透明度 */
	startColorAlpha:Float,

	/** 粒子初始大小方差 */
	startParticleSizeVariance:Int,

	/** 粒子初始颜色绿色分量 */
	startColorGreen:Float,

	/** 粒子每秒旋转角度 */
	rotatePerSecond:Float,

	/** 径向加速度 */
	radialAcceleration:Float,

	/** Y坐标是否翻转 */
	yCoordFlipped:Float,

	/** 发射器类型 */
	emitterType:Float,

	/** 混合函数源 */
	blendFuncSource:Float,

	/** 结束颜色透明度方差 */
	finishColorVarianceAlpha:Float,

	/** 粒子结束旋转角度 */
	rotationEnd:Float,

	/** 初始颜色蓝色分量方差 */
	startColorVarianceBlue:Float,

	/** 每秒旋转角度方差 */
	rotatePerSecondVariance:Float,

	/** 粒子生命周期 */
	particleLifespan:Float,

	/** 最小半径 */
	minRadius:Float,

	/** 配置名称 */
	configName:String,

	/** 切向加速度 */
	tangentialAcceleration:Float,

	/** 粒子初始旋转角度 */
	rotationStart:Float,

	/** 初始颜色绿色分量方差 */
	startColorVarianceGreen:Float,

	/** 粒子速度 */
	speed:Float,

	/** 最小半径方差 */
	minRadiusVariance:Float,

	/** 结束颜色蓝色分量方差 */
	finishColorVarianceBlue:Float,

	/** 结束颜色蓝色分量 */
	finishColorBlue:Float,

	/** 结束颜色绿色分量 */
	finishColorGreen:Float,

	/** 混合函数目标 */
	blendFuncDestination:Float,

	/** 结束颜色透明度 */
	finishColorAlpha:Float,

	/** 源位置X方向方差 */
	sourcePositionVariancex:Float,

	/** 粒子初始大小 */
	startParticleSize:Int,

	/** 源位置Y方向方差 */
	sourcePositionVariancey:Float,

	/** 粒子初始颜色红色分量 */
	startColorRed:Float,

	/** 结束颜色红色分量方差 */
	finishColorVarianceRed:Float,

	/** 是否使用绝对位置 */
	absolutePosition:Bool,

	/** 纹理文件名 */
	textureFileName:String,

	/** 初始颜色透明度方差 */
	startColorVarianceAlpha:Float,

	/** 最大粒子数量 */
	maxParticles:Int,

	/** 结束颜色绿色分量方差 */
	finishColorVarianceGreen:Float,

	/** 粒子结束大小 */
	finishParticleSize:Int,

	/** 发射器持续时间 */
	duration:Float,

	/** 初始颜色红色分量方差 */
	startColorVarianceRed:Float,

	/** 结束颜色红色分量 */
	finishColorRed:Float,

	/** X方向重力 */
	gravityx:Float,

	/** 最大半径方差 */
	maxRadiusVariance:Float,

	/** 结束粒子大小方差 */
	finishParticleSizeVariance:Int,

	/** Y方向重力 */
	gravityy:Float,

	/** 结束旋转角度方差 */
	rotationEndVariance:Float,

	/** 初始颜色蓝色分量 */
	startColorBlue:Float,

	/** 初始旋转角度方差 */
	rotationStartVariance:Float,

	/** 速度方差 */
	speedVariance:Float,

	/** 径向加速度方差 */
	radialAccelVariance:Float,

	/** 切向加速度方差 */
	tangentialAccelVariance:Float,

	/** 粒子生命周期方差 */
	particleLifespanVariance:Float,

	/** 角度方差 */
	angleVariance:Float,

	/** 发射角度 */
	angle:Float,

	/** 最大半径 */
	maxRadius:Float
}
