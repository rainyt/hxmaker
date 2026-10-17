package hx.effect3d;

import hx.geom.Vector3D;
import hx.render3d.Math3D;

/** 发射配置；每次 update 校验。模拟空间在 play 时锁定，其余参数可动态修改。 */
class ParticleSettings3D {
	public var maxParticles:Int = 256;
	/** 每秒发射数；超出容量的粒子丢弃，不积压。 */
	public var emissionRate:Float = 20;
	/** play 时立即发射的粒子数量。 */
	public var burst:Int = 0;
	/** 发射持续秒数；零表示持续发射，stop 后自然收尾。 */
	public var duration:Float = 1;
	public var lifetimeMin:Float = 0.5;
	public var lifetimeMax:Float = 1;
	public var speedMin:Float = 1;
	public var speedMax:Float = 2;
	public var sizeMin:Float = 0.2;
	public var sizeMax:Float = 0.5;
	/** 绕局部 +Y 发射的圆锥半角，零为定向，180 为整球方向。 */
	public var coneAngle:Float = 30;
	/** 均匀体积分布的球形发射区域；零为点发射器。 */
	public var radius:Float = 0;
	public var gravity:Vector3D = new Vector3D(0, -1, 0);
	/** 世界空间粒子脱离发射节点移动；局部空间粒子跟随节点。 */
	public var worldSpace:Bool = true;
	public var rotationMin:Float = 0;
	public var rotationMax:Float = 360;
	/** 角速度，单位为度每秒。 */
	public var angularVelocity:Float = 0;
	public var size:FloatCurve3D = new FloatCurve3D([0., 1.], [1., 0.]);
	public var alpha:FloatCurve3D = new FloatCurve3D([0., 0.7, 1.], [1., 1., 0.]);
	/** RGB 通道曲线，输出限制到零至一；再与材质颜色相乘。 */
	public var red:FloatCurve3D = FloatCurve3D.constant(1);
	public var green:FloatCurve3D = FloatCurve3D.constant(1);
	public var blue:FloatCurve3D = FloatCurve3D.constant(1);
	public var sheet:SpriteSheet3D = new SpriteSheet3D();

	public function new() {}

	public function validate():Void {
		if (gravity == null || size == null || alpha == null || red == null || green == null || blue == null || sheet == null)
			throw "粒子曲线、重力和图集不能为空";
		for (v in [emissionRate, duration, lifetimeMin, lifetimeMax, speedMin, speedMax, sizeMin, sizeMax,
			coneAngle, radius, gravity.x, gravity.y, gravity.z, rotationMin, rotationMax, angularVelocity])
			if (!Math3D.finite(v)) throw "粒子参数必须是有限数值";
		if (maxParticles < 1 || maxParticles > 16383 || burst < 0 || emissionRate < 0 || duration < 0
			|| lifetimeMin <= 0 || lifetimeMax < lifetimeMin || speedMin < 0 || speedMax < speedMin
			|| sizeMin < 0 || sizeMax < sizeMin || coneAngle < 0 || coneAngle > 180 || radius < 0 || rotationMax < rotationMin)
			throw "粒子参数范围无效，容量必须介于一至 16383";
	}
}
