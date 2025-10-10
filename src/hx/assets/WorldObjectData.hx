package hx.assets;

#if echo
import echo.Body;
import echo.math.Vector2;
#end

class WorldObjectData {
	/**
	 * 当前WorldObjectData全局数据
	 */
	public static var current:WorldObjectData;

	public var data:Dynamic;

	public function new(data:Dynamic) {
		this.data = data;
	}

	public function getConfig(id:String):ObjectConfig {
		var array:Array<ObjectConfig> = data.objects;
		for (index => value in array) {
			if (value.id == id) {
				return value;
			}
		}
		return null;
	}

	#if echo
	/**
	 * 创建碰撞块
	 * @param id 
	 * @return Shape
	 */
	public function createEchoCollision(id:String):Body {
		var config = getConfig(id);
		switch config.collisionType {
			case POLYGON:
				var points:Array<Vector2> = [];
				var len = Std.int(config.points.length / 2);
				for (i in 0...len) {
					points.push(new Vector2(config.points[i * 2], config.points[i * 2 + 1]));
				}
				return new Body({
					mass: STATIC,
					shape: {
						type: POLYGON,
						vertices: points
					}
				});

			case CIRCLE:
				return new Body({
					mass: STATIC,
					shape: {
						type: CIRCLE,
						radius: config.radian
					}
				});
		}
	}
	#end
}

typedef ObjectConfig = {
	id:String,
	offestX:Float,
	offestY:Float,
	collisionType:CollisionType,
	points:Array<Float>,
	radian:Float,
	classType:String,
	type:String,
	path:String,
}

enum abstract CollisionType(String) to String from String {
	var POLYGON = "polygon";

	var CIRCLE = "circle";
}
