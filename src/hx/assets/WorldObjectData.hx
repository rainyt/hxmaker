package hx.assets;

// import org.poly2tri.VisiblePolygon;
// import org.poly2tri.Point;
// import org.poly2tri.SweepContext;
// import org.poly2tri.Sweep;
import hx.utils.Log;
import haxe.Json;
#if echo
import echo.Body;
import echo.math.Vector2;
#end

/**
 * world_object.json数据结构数据
 */
class WorldObjectData {
	/**
	 * 当前WorldObjectData全局数据
	 */
	public static var current:WorldObjectData;

	public var data:Dynamic;

	/**
	 * 对象列表
	 */
	public var objects:Array<ObjectData> = [];

	/**
	 * 对象键值映射支持
	 */
	public var objectsMapIds:Map<String, ObjectData> = [];

	/**
	 * 组对象列表
	 */
	public var groupObjects:Array<GroupObjectData> = [];

	/**
	 * 根路径
	 */
	public var rootPath:String;

	public function new(rootPath:String, data:Dynamic) {
		this.rootPath = rootPath;
		this.data = data;
		for (key in Reflect.fields(data)) {
			Reflect.setProperty(this, key, Reflect.getProperty(data, key));
		}
		for (item in this.objects) {
			objectsMapIds.set(item.id, item);
		}
	}

	#if echo
	/**
	 * 创建碰撞块
	 * @param id 
	 * @return Shape
	 */
	public function createEchoCollision(id:String):Body {
		var config = getObjectDataById(id);
		switch config.collisionType {
			case POLYGON:
				if (config.points == null) {
					Log.warring("WorldObjectData.createEchoCollision id: " + id + ", points is null");
					return null;
				}
				var points:Array<Vector2> = [];
				var sweepPoints:Array<Point> = [];
				var len = Std.int(config.points.length / 2);
				for (i in 0...len) {
					points.push(new Vector2(config.points[i * 2], config.points[i * 2 + 1]));
					// sweepPoints.push(new Point(config.points[i * 2], config.points[i * 2 + 1]));
				}
				forceClockwise(points);
				// if (false && isConcave(points)) {
				// 	for (vector2 in points) {
				// 		sweepPoints.push(new Point(vector2.x, vector2.y));
				// 	}
				// 	// TODO 这里需要实现凹凸碰撞块，拆分多个碰撞块，每个碰撞块的碰撞类型为POLYGON
				// 	var polygon = new VisiblePolygon();
				// 	polygon.addPolyline(sweepPoints);
				// 	polygon.performTriangulationOnce();
				// 	var triangles = polygon.getVerticesAndTriangles();
				// 	// trace("三角形：", triangles);

				// 	var trianglesCount:Int = Std.int(triangles.triangles.length / 3);
				// 	// 使用分割处理，将三角形拆分成多个碰撞块
				// 	var vertices = triangles.vertices;
				// 	var body = new Body({
				// 		mass: STATIC
				// 	});
				// 	for (i in 0...trianglesCount) {
				// 		var a = triangles.triangles[i * 3];
				// 		var b = triangles.triangles[i * 3 + 1];
				// 		var c = triangles.triangles[i * 3 + 2];
				// 		body.create_shape({
				// 			type: POLYGON,
				// 			vertices: [
				// 				new Vector2(vertices[a * 3], vertices[a * 3 + 1]),
				// 				new Vector2(vertices[b * 3], vertices[b * 3 + 1]),
				// 				new Vector2(vertices[c * 3], vertices[c * 3 + 1])
				// 			]
				// 		});
				// 	}
				// 	return body;
				// } else {
				return new Body({
					mass: STATIC,
					shape: {
						type: POLYGON,
						vertices: points
					}
				});
			// }

			case CIRCLE:
				return new Body({
					mass: STATIC,
					shape: {
						type: CIRCLE,
						radius: config.radian,
						offset_x: config.collisionX,
						offset_y: config.collisionY
					}
				});
		}
	}
	#end

	#if echo
	/**
	 * 确保点集是顺时针方向
	 * @param points 顶点数组 [{x:Float, y:Float}]
	 * @param yUp 是否为笛卡尔坐标系（y轴向上）。如果y轴向下（普通屏幕坐标），请传 false。
	 */
	public function forceClockwise(points:Array<Vector2>, yUp:Bool = false):Void {
		var area:Float = 0;

		for (i in 0...points.length) {
			var p1 = points[i];
			var p2 = points[(i + 1) % points.length];
			// 鞋带公式计算有符号面积
			area += (p2.x - p1.x) * (p2.y + p1.y);
		}

		// 在 y 轴向下的坐标系中：
		// area > 0 表示顺时针 (CW)
		// area < 0 表示逆时针 (CCW)

		var isCurrentlyClockwise = yUp ? (area < 0) : (area > 0);

		if (isCurrentlyClockwise) {
			points.reverse(); // 如果不是顺时针，直接原地翻转
		}
	}

	/**
	 * 判断是否是凹边形
	 * @param points 
	 * @return Bool
	 */
	public function isConcave(points:Array<Vector2>):Bool {
		if (points.length < 4)
			return false; // 三角形必定是凸的

		var lastSign:Float = 0;
		var n = points.length;

		for (i in 0...n) {
			var p1 = points[i];
			var p2 = points[(i + 1) % n];
			var p3 = points[(i + 2) % n];

			// 计算向量 (p2-p1) 和 (p3-p2) 的叉积
			var crossProduct = (p2.x - p1.x) * (p3.y - p2.y) - (p2.y - p1.y) * (p3.x - p2.x);

			if (crossProduct != 0) {
				if (lastSign == 0) {
					lastSign = crossProduct;
				} else if ((crossProduct > 0 && lastSign < 0) || (crossProduct < 0 && lastSign > 0)) {
					return true; // 转向改变，说明是凹的
				}
			}
		}
		return false;
	}
	#end

	/**
	 * 删除组数据
	 * @param id 
	 */
	public function removeGroupData(id:String):Void {
		for (item in groupObjects) {
			if (item.id == id) {
				this.groupObjects.remove(item);
				break;
			}
		}
		#if editer
		cast(World.currentWorld, EditerWorld).postWindowEvent("updateGroupObjects");
		#end
	}

	/**
	 * 开始添加对象
	 * @param data 
	 * @return Bool
	 */
	public function pushObject(data:ObjectData):Bool {
		for (index => v in objects) {
			if (data.id == v.id) {
				return false;
			}
		}
		objects.push(data);
		return true;
	}

	/**
	 * 开始添加对象
	 * @param data 
	 * @return Bool
	 */
	public function removeObject(data:ObjectData):Bool {
		for (v in objects) {
			if (data.id == v.id) {
				objects.remove(v);
				return true;
			}
		}
		return false;
	}

	/**
	 * 修改对象
	 * @param data 
	 * @return Bool
	 */
	public function changeObject(data:ObjectData):Bool {
		for (index => v in objects) {
			if (data.id == v.id) {
				objects[index] = data;
				return true;
			}
		}
		return false;
	}

	/**
	 * 修改对象
	 * @param data 
	 * @return Bool
	 */
	public function changeGroupObject(data:GroupObjectData):Bool {
		for (index => v in groupObjects) {
			if (data.id == v.id) {
				groupObjects[index] = data;
				#if editer
				cast(World.currentWorld, EditerWorld).postWindowEvent("updateGroupObjects");
				#end
				return true;
			}
		}
		return false;
	}

	/**
	 * 获取ObjectData
	 * @param id 
	 * @return ObjectData
	 */
	public function getObjectDataById(id:String, copy:Bool = true):ObjectData {
		var obj = objectsMapIds.get(id);
		if (obj != null) {
			return copy ? Reflect.copy(obj) : obj;
		}
		return null;
	}

	/**
	 * 获得储存数据
	 * @return String
	 */
	public function toString():String {
		return Json.stringify({
			objects: objects,
			groupObjects: groupObjects
		}, "	");
	}
}

enum abstract CollisionType(String) to String from String {
	var POLYGON = "polygon";

	var CIRCLE = "circle";
}

/**
 * 组渲染对象
 */
typedef GroupObjectData = {
	/**
	 * 组ID
	 */
	var id:String;

	/**
	 * 名称
	 */
	var name:String;

	/**
	 * 渲染列表
	 */
	var data:Array<GroupSubObject>;
}

/**
 * 组对象的生成id和坐标位置
 */
typedef GroupSubObject = {
	var id:String;
	var x:Float;
	var y:Float;
	var scaleX:Float;
	var scaleY:Float;
	var rotation:Float;
}

typedef ObjectData = DisplayData & {
	/**
	 * 绑定ObjectData的ID
	 */
	var id:String;

	/**
	 * 资源路径
	 */
	var ?path:String;

	/**
	 * 遮罩资源路径
	 */
	var ?maskPath:String;

	/**
	 * 深度，如果值越高，则处于越低
	 */
	var ?depth:Null<Int>;

	/**
	 * Spine资源路径
	 */
	var ?spinePngFiles:String;

	/**
	 * 是否可以移动
	 */
	var ?immovable:Null<Bool>;

	/**
	 * Spine资源路径
	 */
	var ?spineAtlasFile:String;

	/**
	 * Spine资源路径
	 */
	var ?spineJsonFile:String;

	/**
	 * 精灵图资源路径
	 */
	var ?atlasPngFile:String;

	/**
	 * 精灵图资源路径
	 */
	var ?atlasXmlFile:String;

	/**
	 * 资源类型
	 */
	var type:AssetsType;

	/**
	 * 碰撞类型
	 */
	var ?collisionType:CollisionType;

	/**
	 * 如果是多边形数据，则进行缓存，以便地图加载时可直接使用
	 */
	var ?polygon:Array<Array<Float>>;

	/**
	 * 描述名称
	 */
	var name:String;

	/**
	 * 类型绑定
	 */
	var ?classType:String;

	/**
	 * 游戏中的显示对象的名称
	 */
	var ?displayName:String;

	/**
	 * 偏移X
	 */
	var ?offestX:Null<Float>;

	/**
	 * 偏移Y
	 */
	var ?offestY:Null<Float>;

	/**
	 * 垂直间距
	 */
	var ?vGap:Null<Float>;

	/**
	 * 水平间距
	 */
	var ?hGap:Null<Float>;

	/**
	 * 矩形X轴
	 */
	var ?collisionX:Null<Float>;

	/**
	 * 矩形Y轴
	 */
	var ?collisionY:Null<Float>;

	/**
	 * 矩形宽度
	 */
	var ?rectWidth:Null<Float>;

	/**
	 * 矩形高度
	 */
	var ?rectHeight:Null<Float>;

	/**
	 * 半径
	 */
	var ?radian:Null<Float>;

	/**
	 * 坐标
	 */
	var ?points:Array<Float>;

	/**
	 * 遮罩阴影是否启用
	 */
	var ?maskShadow:Bool;

	/**
	 * 内阴影是否开启，当启动内阴影，则会呈现在图层之上
	 */
	var ?maskInline:Bool;

	/**
	 * 遮罩阴影
	 */
	var ?maskShadowColor:String;

	/**
	 * 遮罩偏移值X
	 */
	var ?maskShadowX:Float;

	/**
	 * 遮罩偏移值Y
	 */
	var ?maskShadowY:Float;

	var ?bottomLight:Bool;
	var ?topLight:Bool;
	var ?shadow:Bool;

	var ?bLightWidth:Float;

	var ?bLightHeight:Float;

	var ?bLightScale:Float;

	var ?bLightColor:UInt;

	var ?shadowWidth:Float;

	var ?shadowHeight:Float;

	var ?shadowScale:Float;

	var ?shadowColor:UInt;

	/**
	 * 必须渲染
	 */
	var ?mustDarw:Bool;
}

typedef DisplayData = {
	/**
	 * 绑定ObjectData的ID
	 */
	var id:String;

	/**
	 * 当ID为null的时候，则会有ClassType参数
	 */
	var ?classType:String;

	/**
	 * 生成的坐标X
	 */
	var ?x:Null<Float>;

	/**
	 * 生成的坐标Y
	 */
	var ?y:Null<Float>;

	/**
	 * 显示对象的名字
	 */
	var ?name:String;

	/**
	 * 队伍值
	 */
	var ?troop:Null<Int>;

	/**
	 * 自定义数据
	 */
	var ?data:Dynamic;

	/**
	 * ScaleX轴
	 */
	var ?scaleX:Null<Float>;

	/**
	 * ScaleY轴
	 */
	var ?scaleY:Null<Float>;

	var ?rotation:Null<Float>;

	/**
	 * 组ID，如果存在组ID，则选中的时候，需要一起选中
	 */
	var ?groupId:String;

	/**
	 * 透明度
	 */
	var ?alpha:Null<Float>;

	/**
	 * 混合模式
	 */
	var ?blendMode:String;
}

/**
 * 资源类型
 */
enum abstract AssetsType(String) to String from String {
	/**
	 * 图片资源
	 */
	var PNG = "png";

	/**
	 * SPINE骨骼资源
	 */
	var SPINE = "spine";

	/**
	 * 精灵图资源
	 */
	var ATLAS = "atlas";

	/**
	 * 地图遮罩资源，该资源会渲染纹理遮罩
	 */
	var MAP_MASK = "map_mask";

	/**
	 * 音频资源
	 */
	var SOUND = "sound";

	/**
	 * 背景音频
	 */
	var MUSIC = "music";

	/**
	 * 自定义类型
	 */
	var CUSTOM = "custom";
}
