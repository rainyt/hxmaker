package game.worlds;

#if differ
import hx.display.Graphics;
import differ.ShapeDrawer;

/**
 * 使用`differ`库时可使用的Debug碰撞体渲染
 */
class DifferDebug extends ShapeDrawer {
	/**
	 * 图形渲染器
	 */
	public var graphics:Graphics = new Graphics();

	/**
	 * 重置
	 */
	public function reset() {
		graphics.clear();
		graphics.beginLineStyle(0xff0000, 1);
	}

	/**
	 * 绘制线条
	 * @param p0x 
	 * @param p0y 
	 * @param p1x 
	 * @param p1y 
	 * @param startPoint 
	 */
	override function drawLine(p0x:Float, p0y:Float, p1x:Float, p1y:Float, ?startPoint:Bool = true) {
		if (startPoint) {
			graphics.moveTo(p0x, p0y);
			graphics.lineTo(p1x, p1y);
		} else {
			graphics.lineTo(p1x, p1y);
		}
	}
}
#end
