package hx.assets;

import hx.ui.UIManager;
import hx.ui.UIAssets;
import hx.assets.SpineTextureAtlas;
import hx.events.FutureErrorEvent;
import hx.assets.Atlas;
import haxe.io.Path;
import hx.assets.StyleFuture;
import hx.display.BitmapData;

/**
 * 资源管理器
 */
class Assets extends Future<Assets, Dynamic> {
	/**
	 * 原生路径
	 */
	public var nativePath:String = "";

	/**
	 * 正在加载的资源管理器
	 */
	private static var __assets:Array<Assets> = [];

	/**
	 * 重新再请求加载下一个
	 */
	private static function readyLoadNext():Void {
		trace("尝试下一个加载");
		for (assets in __assets) {
			if (assets != null) {
				if (assets.loadNext()) {
					break;
				}
			}
		}
	}

	/**
	 * 对路径进行格式化
	 * @param path 
	 * @return String
	 */
	public static function formatName(data:Dynamic):String {
		var path:String = null;
		if (data is String) {
			path = data;
		} else {
			var loadData:LoadData = data;
			path = loadData.path;
		}
		var name = Path.withoutExtension(Path.withoutDirectory(path));
		return name;
	}

	/**
	 * 最大同时加载的资源数量
	 */
	public static var MAX_ASSETS_LOAD_COUNTS = 20;

	/**
	 * 当前正在加载的资源数量
	 */
	public static var CURRENT_LOAD_COUNTS:Int = 0;

	/**
	 * 加载的资源列表
	 */
	public var futures:Array<Future<Dynamic, Dynamic>> = [];

	/**
	 * 位图列表
	 */
	public var bitmapDatas:Map<String, BitmapData> = new Map();

	/**
	 * 精灵图图集列表
	 */
	public var atlases:Map<String, Atlas> = new Map();

	/**
	 * Objects列表
	 */
	public var objects:Map<String, Dynamic> = new Map();

	/**
	 * String列表
	 */
	public var strings:Map<String, String> = new Map();

	/**
	 * XML列表
	 */
	public var xmls:Map<String, Xml> = new Map();

	/**
	 * UI资源列表
	 */
	public var uiAssetses:Map<String, UIAssets> = new Map();

	/**
	 * 音乐列表
	 */
	public var sounds:Map<String, Sound> = new Map();

	/**
	 * 样式配置
	 */
	public var styles:Map<String, Xml> = new Map();

	/**
	 * 已经加载完成的数量
	 */
	public var loadedCounts:Int = 0;

	/**
	 * 可预加载的资源数量
	 */
	public var totalCounts:Int = 0;

	/**
	 * 是否正在加载中
	 */
	public var loading:Bool = false;

	/**
	 * 资源是否共享绑定，默认为`false`，如果该Assets可以被`UIManager`读取，则该值会为`true`
	 */
	public var isBindAssets(get, never):Bool;

	private var __isBindAssets:Bool = false;

	private function get_isBindAssets():Bool {
		return this.__isBindAssets;
	}

	/**
	 * 目前加载的索引
	 */
	private var __loadIndex:Int = 0;

	/**
	 * 构造一个资源管理器
	 */
	public function new() {
		super(null, false);
	}

	public function getNativePath(path:String):String {
		if (path.toLowerCase().indexOf(nativePath.toLowerCase()) == -1) {
			return Path.join([nativePath, path]);
		}
		return path;
	}

	/**
	 * 加载音乐资源
	 * @param path 
	 */
	public function loadSound(path:String):Void {
		path = getNativePath(path);
		pushFuture(new hx.assets.SoundFuture(path, false));
	}

	/**
	 * 加载位图资源
	 * @param path 
	 * @return Future<BitmapData>
	 */
	public function loadBitmapData(path:String) {
		path = getNativePath(path);
		if (!isBindAssets || UIManager.getBitmapData(formatName(path)) == null) {
			pushFuture(new hx.assets.BitmapDataFuture(path, false));
		} else {
			trace("已经加载了", path);
		}
	}

	/**
	 * 加载图集资源
	 * @param path 
	 * @param xml 
	 */
	public function loadAtlas(path:String, xml:String) {
		path = getNativePath(path);
		xml = getNativePath(xml);
		pushFuture(new hx.assets.TextureAtlasFuture({
			png: path,
			xml: xml,
			path: path
		}, false));
	}

	/**
	 * 加载Spine图集资源
	 * @param png 
	 * @param atlas 
	 */
	public function loadSpineAtlas(png:String, atlas:String) {
		png = getNativePath(png);
		atlas = getNativePath(atlas);
		pushFuture(new hx.assets.SpineTextureAtlasFuture({
			png: png,
			atlas: atlas,
			path: png
		}, false));
	}

	/**
	 * 加载Json数据
	 * @param path 
	 */
	public function loadJson(path:String) {
		path = getNativePath(path);
		pushFuture(new hx.assets.JsonFuture(path, false));
	}

	/**
	 * 加载字符串
	 * @param path 
	 */
	public function loadString(path:String) {
		path = getNativePath(path);
		pushFuture(new hx.assets.StringFuture(path, false));
	}

	/**
	 * 加载xml数据
	 * @param path 
	 */
	public function loadXml(path:String) {
		path = getNativePath(path);
		pushFuture(new hx.assets.XmlFuture(path, false));
	}

	/**
	 * 加载UI资源
	 * @param path 
	 */
	public function loadUIAssets(path:String) {
		path = getNativePath(path);
		var loader = new hx.assets.UIAssetsFuture(path, false);
		loader.nativePath = this.nativePath;
		pushFuture(loader);
	}

	/**
	 * 加载样式
	 * @param xml 
	 */
	public function loadStyle(xml:String):Void {
		xml = getNativePath(xml);
		var loader = new hx.assets.StyleFuture(xml, false);
		loader.nativePath = nativePath;
		pushFuture(loader);
	}

	/**
	 * 追加到加载队列
	 * @param future 
	 */
	public function pushFuture(future:Future<Dynamic, Dynamic>) {
		if (loading)
			throw "Assets: can't push future when loading";
		futures.push(future);
		future.onComplete((data) -> {
			__onCompleted(future, data);
		});
		future.onError(__onError);
	}

	/**
	 * 开始加载资源
	 */
	public function start():Void {
		if (loading)
			return;
		if (futures.length == 0) {
			// 无资产需要加载，直接完成
			this.completeValue(this);
			__assets.remove(this);
			this.stop();
			return;
		}
		loading = true;
		this.totalCounts = futures.length;
		this.loadedCounts = 0;
		loadNext();
		__assets.push(this);
	}

	/**
	 * 停止加载
	 */
	public function stop():Void {
		// 这里应该停止所有加载流程
		loading = false;
		__assets.remove(this);
	}

	/**
	 * 准备加载下一个
	 */
	private function loadNext():Bool {
		var future = futures[__loadIndex];
		if (future == null) {
			return false;
		}
		trace("CURRENT_LOAD_COUNTS", CURRENT_LOAD_COUNTS);
		trace("剩余", future.getLoadData());
		if (CURRENT_LOAD_COUNTS < MAX_ASSETS_LOAD_COUNTS) {
			CURRENT_LOAD_COUNTS++;
			trace("开始加载：", future.getLoadData());
			future.post();
			__loadIndex++;
			loadNext();
			return true;
		}
		return false;
	}

	public function pushAssets(assets:Assets):Void {
		for (key => value in assets.bitmapDatas) {
			this.bitmapDatas.set(key, value);
		}
		for (key => value in assets.sounds) {
			this.sounds.set(key, value);
		}
		for (key => value in assets.xmls) {
			this.xmls.set(key, value);
		}
		for (key => value in assets.objects) {
			this.objects.set(key, value);
		}
		for (key => value in assets.styles) {
			this.styles.set(key, value);
		}
		for (key => value in assets.atlases) {
			this.atlases.set(key, value);
		}
		for (key => value in assets.sounds) {
			this.sounds.set(key, value);
		}
		for (key => value in assets.uiAssetses) {
			this.uiAssetses.set(key, value);
		}
		for (key => value in assets.strings) {
			this.strings.set(key, value);
		}
	}

	public function clean(dispose:Bool = true):Void {
		if (dispose) {
			for (data in this.bitmapDatas) {
				// TODO 应该清理
			}
			for (assets in this.uiAssetses) {
				assets.clean();
			}
		}
		this.bitmapDatas.clear();
		this.atlases.clear();
		this.sounds.clear();
		this.uiAssetses.clear();
		this.objects.clear();
		this.styles.clear();
		this.xmls.clear();
		this.strings.clear();
	}

	/**
	 * 加成完成时触发
	 * @param future 
	 */
	private function __onCompleted(future:Future<Dynamic, Dynamic>, data:Dynamic):Void {
		CURRENT_LOAD_COUNTS--;
		loadedCounts++;
		if (data is StyleAssets) {
			var style:StyleAssets = cast data;
			this.pushAssets(style);
			style.clean(false);
		} else if (data is Sound) {
			sounds.set(formatName(future.getLoadData()), data);
		} else if (data is UIAssets) {
			uiAssetses.set(formatName(future.getLoadData()), data);
		} else if (data is Xml) {
			xmls.set(formatName(future.getLoadData()), data);
		} else if (data is String) {
			strings.set(formatName(future.getLoadData()), data);
		} else if (data is BitmapData) {
			bitmapDatas.set(formatName(future.getLoadData()), data);
		} else if (data is Atlas) {
			atlases.set(formatName(future.getLoadData()), data);
		} else if (data is SpineTextureAtlas) {
			atlases.set(formatName(future.getLoadData()), data);
		} else {
			objects.set(formatName(future.getLoadData()), data);
		}
		trace("Assets: loaded ", loadedCounts, totalCounts, __loadIndex);
		if (loadedCounts == totalCounts) {
			this.completeValue(this);
			__assets.remove(this);
			this.stop();
			return;
		}
		if (loading)
			readyLoadNext();
	}

	/**
	 * 加载失败时触发
	 * @param future 
	 */
	private function __onError(error:Dynamic):Void {
		CURRENT_LOAD_COUNTS--;
		trace(error);
		this.errorValue(FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "Load fail."));
	}

	/**
	 * 获得位图数据，精灵图可以通过`精灵图:精灵名称`处理
	 * @param name 
	 * @return BitmapData
	 */
	public function getBitmapData(name:String):BitmapData {
		if (name == null)
			return null;
		if (name.indexOf(":") != -1) {
			var arr = name.split(":");
			var atlas = atlases.get(arr[0]);
			if (atlas != null) {
				var bitmapData = atlas.bitmapDatas.get(arr[1]);
				if (bitmapData != null) {
					return bitmapData;
				}
			}
		}
		var bitmapData = bitmapDatas.get(name);
		if (bitmapData == null) {
			// 如果仍然没有，则从加载的资源列表中获得
			for (assets in uiAssetses) {
				var bmd = assets.getBitmapData(name);
				if (bmd != null) {
					return bmd;
				}
			}
		}
		return bitmapData;
	}
}
