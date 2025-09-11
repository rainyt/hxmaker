package hx.display;

#if echo
import echo.util.Debug;

/**
 * 基于Echo的图形调试工具
 */
class EchoDebug extends Debug {
	/**
	 * 图形调试渲染对象
	 */
	public var canvas:Graphics;

	public function new() {
		shape_color = 0x005b6ee1;
		shape_fill_color = 0x00cbdbfc;
		shape_collided_color = 0x00d95763;
		quadtree_color = 0x00847e87;
		quadtree_fill_color = 0x009badb7;
		intersection_color = 0x00cbdbfc;
		intersection_overlap_color = 0x00d95763;
		world_bounds_color = 0x0087b691;

		canvas = new Graphics();
	}

	override public inline function draw_line(from_x:Float, from_y:Float, to_x:Float, to_y:Float, color:Int, alpha:Float = 1.) {
		canvas.beginLineStyle(color, 1);
		canvas.moveTo(from_x, from_y);
		canvas.lineTo(to_x, to_y, true, alpha);
	}

	override public inline function draw_rect(min_x:Float, min_y:Float, width:Float, height:Float, color:Int, ?stroke:Int, alpha:Float = 1.) {
		canvas.beginFill(color);
		canvas.drawRect(min_x, min_y, width, height, alpha);
		if (stroke != null) {
			canvas.beginLineStyle(stroke, 1);
			canvas.moveTo(min_x, min_y);
			canvas.lineTo(min_x + width, min_y);
			canvas.lineTo(min_x + width, min_y + height);
			canvas.lineTo(min_x, min_y + height);
			canvas.lineTo(min_x, min_y);
		}
	}

	override public inline function draw_circle(x:Float, y:Float, radius:Float, color:Int, ?stroke:Int, alpha:Float = 1.) {
		// canvas.beginFill(color);
		// canvas.graphics.beginFill(color, alpha);
		// stroke != null ? canvas.graphics.lineStyle(1, stroke, 1) : canvas.graphics.lineStyle();
		// canvas.graphics.drawCircle(x, y, radius);
		// canvas.graphics.endFill();
	}

	override public inline function clear() {
		canvas.clear();
	}
}
#end
