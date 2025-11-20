package hx.assets;

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
						radius: config.radian,
						offset_x: config.collisionX,
						offset_y: config.collisionY
					}
				});
		}
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
