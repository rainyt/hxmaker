package hx.utils;

/**
 * 数学工具类，提供常用的数学计算方法
 */
class MathUtils {
	/**
	 * 将角度转换为弧度
	 * @param rotation 角度值
	 * @return 转换后的弧度值
	 */
	public static function rotationToRadian(rotation:Float):Float {
		return rotation * Math.PI / 180;
	}

	/**
	 * 将弧度转换为角度
	 * @param radian 弧度值
	 * @return 转换后的角度值
	 */
	public static function radianToRotation(radian:Float):Float {
		return radian * 180 / Math.PI;
	}
}
