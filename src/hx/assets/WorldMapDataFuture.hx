package hx.assets;

import hx.assets.WorldObjectData.DisplayData;
import haxe.Json;
import hx.assets.StringFuture;
import hx.assets.StyleFuture.StyleAssets;
import hx.assets.Future;

using haxe.io.Path;

/**
 * 加载世界地图资源
 */
class WorldMapDataFuture extends Future<StyleAssets, String> {
	override function post() {
		var path = getLoadData();
		var dir = path.directory().directory();
		new StringFuture(getLoadData()).onComplete(map -> {
			var mapData = Json.parse(map);
			var assets = new WorldMapDataAssets(mapData);
			assets.objects.set(path.withoutExtension().withoutDirectory(), assets.worldMapData);
			for (file in assets.worldMapData.files) {
				var config = WorldObjectData.current.getObjectDataById(file.id);
				switch config.type {
					case "png":
						assets.loadBitmapData(Path.join([dir, config.path]));
					default:
						throw "unknown type" + config.type;
				}
			}
			assets.onComplete(a -> {
				this.completeValue(assets);
			}).onError(errorValue);
			assets.start();
		}).onError(this.errorValue);
	}
}

class WorldMapDataAssets extends StyleAssets {
	public var worldMapData:WorldMapData;

	public function new(data:Dynamic) {
		super();
		worldMapData = new WorldMapData(data);
	}
}

/**
 * 世界地图数据
 */
class WorldMapData {
	/**
	 * 子世界
	 */
	public var subWorlds:Array<SubWorldConfig> = [];

	/**
	 * 世界名
	 */
	public var name:String;

	/**
	 * 该世界所需要的所有资源文件
	 */
	public var files:Array<WorldFile> = [];

	/**
	 * 事件列表
	 */
	public var events:Array<WorldEventData> = [];

	/**
	 * 根据项目ID获得
	 * @param path 
	 */
	public function new(data:Dynamic) {
		this.parserWorldProjectData(data);
	}

	/**
	 * 解析WorldProjectData数据
	 * @param data 
	 */
	public function parserWorldProjectData(data:WorldProjectData):Void {
		for (key in Reflect.fields(data)) {
			Reflect.setProperty(this, key, Reflect.getProperty(data, key));
		}
	}
}

/**
 * 世界Project数据
 */
typedef WorldProjectData = {
	?subWorlds:Array<SubWorldConfig>,
	?name:String,
	?files:Array<WorldFile>,
	?events:Array<WorldEventData>
}

/**
 * 世界事件
 */
typedef WorldEventData = {
	/**
	 * 事件坐标X
	 */
	var ?x:Float;

	/**
	 * 事件坐标Y
	 */
	var ?y:Float;

	/**
	 * 事件宽度
	 */
	var ?width:Float;

	/**
	 * 事件高度
	 */
	var ?height:Float;

	/**
	 * 事件名称
	 */
	var name:String;

	/**
	 * ID名
	 */
	var ?id:String;

	/**
	 * 颜色
	 */
	var ?color:UInt;
}

/**
 * 世界所需文件
 */
typedef WorldFile = {
	/**
	 * 资源ID
	 */
	var id:String;
}

/**
 * 世界加载事件
 */
typedef WorldLoadEvent = {
	code:Int,
	progress:Float,
	?errorMsg:String
}

/**
 * 子项世界配置
 */
typedef SubWorldConfig = {
	/**
	 * 世界描述名
	 */
	var name:String;

	/**
	 * 唯一ID
	 */
	var id:String;

	/**
	 * 世界宽度
	 */
	var width:Int;

	/**
	 * 世界高度
	 */
	var height:Int;

	/**
	 * 	世界X轴
	 */
	var x:Int;

	/**
	 * 世界Y轴
	 */
	var y:Int;

	/**
	 * 背景颜色，当不存在backgrounds时，则会以该值作为默认值
	 */
	var ?color:Null<UInt>;

	var bottomDisplays:Array<DisplayData>;
	var boxDisplays:Array<DisplayData>;
	var topDisplays:Array<DisplayData>;
	var backgrounds:Array<BackgroudConfig>;

	var ?events:Array<WorldEventData>;
	/**
	 * 一般创建Rogoulike地图时会产生此数据
	 */
	// var ?worldRoomData:WorldRoomData;
}

/**
 * 背景配置
 */
typedef BackgroudConfig = {
	/**
	 * 绑定的资源ID，当`type`为`IMAGE`时需要
	 */
	var ?id:String;

	/**
	 * 背景类型
	 */
	var ?type:BackgroundConfigType;

	/**
	 * 背景颜色，如果是纯色块时使用
	 */
	var ?color:UInt;

	/**
	 * 遮罩ID，暂未实现，请忽略
	 */
	var ?maskid:String;
}

enum abstract BackgroundConfigType(String) {
	/**
	 * 图片来源
	 */
	var IMAGE = "image";

	/**
	 * 纯色块
	 */
	var COLOR = "color";
}
