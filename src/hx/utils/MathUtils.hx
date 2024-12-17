package hx.utils;

class MathUtils {
	/**
	 * 角度转弧度
	 * @param rotation 
	 * @return Float
	 */
	public static function rotationToRadian(rotation:Float):Float {
		return rotation * Math.PI / 180;
	}
}
