package hx.assets;

import hx.utils.Timer;
import spine.SkeletonData;
import hx.display.Spine;
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
	 * 最大尝试重新载入次数，如果连续失败6次，则会触发全局事件`Event.ASSETS_LOAD_ERROR`
	 */
	public static var MAX_TRY_LOAD_TIMES = 6;

	/**
	 * 尝试重新加载次数
	 */
	private var __tryLoadTimes:Int = 0;

	/**
	 * 资源名称
	 */
	public var name:String;

	/**
	 * 尝试重新加载次数
	 */
	public var tryLoadTimes:Int = MAX_TRY_LOAD_TIMES;

	/**
	 * 默认原生路径
	 */
	public static var defaultNativePath:String = null;

	public static function getDefaultNativePath(path:String):String {
		if (path.indexOf("http") == 0) {
			return path;
		}
		if (defaultNativePath != null && path.indexOf(defaultNativePath) == -1) {
			return Path.join([defaultNativePath, path]);
		}
		return path;
	}

	/**
	 * 原生路径
	 */
	public var nativePath:String = null;

	/**
	 * 正在加载的资源管理器
	 */
	private static var __assets:Array<Assets> = [];

	/**
	 * 重新再请求加载下一个
	 */
	private static function readyLoadNext():Void {
		trace("尝试加载下一个资源");
		for (assets in __assets) {
			if (assets != null) {
				if (assets.loadNext()) {
					return;
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
	 * 父节点资源节点
	 */
	public var parent:Assets;

	/**
	 * 音乐列表
	 */
	public var sounds:Map<String, Sound> = new Map();

	/**
	 * 样式配置
	 */
	public var styles:Map<String, Xml> = new Map();

	/**
	 * 资源压缩包
	 */
	public var zips:Map<String, Zip> = new Map();

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

	/**
	 * 获取资源的原生路径
	 * @param path 
	 * @return String
	 */
	public function getNativePath(path:String):String {
		if (this.nativePath != null && path.toLowerCase().indexOf(nativePath.toLowerCase()) == -1) {
			return Path.join([nativePath, path]);
		}
		return path;
	}

	/**
	 * 判断此项资源是否已加载
	 * @param future 
	 * @return Bool
	 */
	public function hasLoading(future:Future<Dynamic, Dynamic>):Bool {
		var id = Assets.formatName(future.path);
		if (UIManager.getBitmapData(id) != null) {
			return true;
		}
		if (UIManager.getSound(id) != null) {
			return true;
		}
		if (UIManager.getString(id) != null) {
			return true;
		}
		if (UIManager.getAtlas(id) != null) {
			return true;
		}
		if (UIManager.getSkeletonData(id) != null) {
			return true;
		}
		if (UIManager.getUIAssets(id) != null) {
			return true;
		}

		for (f in futures) {
			if (f.path == future.path) {
				return true;
			}
		}
		return false;
	}

	/**
	 * 加载zip包文件
	 * @param path 
	 */
	public function loadZip(path:String):Void {
		pushFuture(new hx.assets.ZipFuture(path, false));
	}

	/**
	 * 加载音乐资源
	 * @param path 
	 * @param isMusic 是否为音乐资源，默认为`false`，如果为`true`，在某些平台上，如Android，会将该资源加载为音乐资源，而不是普通的音效资源
	 */
	public function loadSound(path:String, isMusic:Bool = false):Void {
		#if !hxmaker_editer
		path = getNativePath(path);
		var future = new hx.assets.SoundFuture(path, false);
		future.isMusic = isMusic;
		pushFuture(future);
		#end
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
			#if assets_debug
			trace("已经加载了", path);
			#end
		}
	}

	/**
	 * 加载纹理字体资源，XML格式
	 * @param png 
	 * @param xml 
	 */
	public function loadFnt(png:String, xml:String) {
		var path = getNativePath(png);
		xml = getNativePath(xml);
		pushFuture(new hx.assets.FntFuture({
			png: path,
			xml: xml,
			path: path
		}, false));
	}

	/**
	 * 加载图集资源
	 * @param path 
	 * @param xml 
	 */
	public function loadAtlas(png:String, xml:String) {
		var path = getNativePath(png);
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
		future.autoPost = false;
		if (loading)
			throw "Assets: can't push future when loading";
		if (hasLoading(future)) {
			return;
		}
		futures.push(future);
		future.onComplete((data) -> {
			onCompleted(future, data);
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
		__loadIndex = 0;
		loading = true;
		this.isComplete = false;
		this.isError = false;
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
		this.progressValue(this.getProgress());
		var future = futures[__loadIndex];
		if (future == null) {
			return false;
		}
		#if assets_debug
		trace("开始加载：", future.getLoadData());
		#end
		__loadIndex++;
		if (!future.isComplete) {
			future.post();
		} else {
			loadedCounts++;
			#if assets_debug
			trace("已完成加载，跳过：", future.getLoadData());
			#end
		}
		loadNext();
		return true;
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
	 * 获得已加载进度
	 * @return Float
	 */
	public function getProgress():Float {
		return loadedCounts / totalCounts;
	}

	/**
	 * 加成完成时触发
	 * @param future 
	 */
	private function onCompleted(future:Future<Dynamic, Dynamic>, data:Dynamic):Void {
		// CURRENT_LOAD_COUNTS--;
		loadedCounts++;
		if (data is Zip) {
			var zip:Zip = cast data;
			this.zips.set(formatName(future.getLoadData()), zip);
		} else if (data is StyleAssets) {
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
		#if assets_debug
		trace("Assets: loaded ", future.path, loadedCounts, totalCounts, __loadIndex);
		#end
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
		// CURRENT_LOAD_COUNTS--;
		if (error is FutureErrorEvent)
			this.errorValue(error);
		else
			this.errorValue(FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "Load fail:" + error));
	}

	/**
	 * 获得SkeletonData数据
	 * @param name spine名称
	 * @param json 如果不提供，则自动以name为命名获得
	 * @return SkeletonData
	 */
	public function getSkeletonData(name:String, json:String = null):SkeletonData {
		if (json == null)
			json = name;
		var atlas:Atlas = getAtlas(name);
		if (atlas is SpineTextureAtlas) {
			var spineAtlas:SpineTextureAtlas = cast atlas;
			return spineAtlas.createSkeletonData(this.getString(json));
		}
		return null;
	}

	/**
	 * 获得精灵图
	 * @param name 
	 * @return Atlas
	 */
	public function getAtlas(name:String):Atlas {
		var atlas = atlases.get(name);
		if (atlas == null) {
			for (assets in uiAssetses) {
				atlas = assets.getAtlas(name);
				if (atlas != null) {
					return atlas;
				}
			}
		}
		return atlas;
	}

	/**
	 * 获得字符串
	 * @param name 
	 * @return String
	 */
	public function getString(name:String):String {
		var str = strings.get(name);
		if (str == null) {
			for (assets in uiAssetses) {
				str = assets.getString(name);
				if (str != null) {
					return str;
				}
			}
		}
		return str;
	}

	/**
	 * 获得Object
	 * @param name 
	 * @return String
	 */
	public function getObject(name:String):Dynamic {
		var obj = objects.get(name);
		if (obj == null) {
			for (assets in uiAssetses) {
				obj = assets.getObject(name);
				if (obj != null) {
					return obj;
				}
			}
		}
		return obj;
	}

	/**
	 * 获得音频
	 * @param name 
	 * @return Sound
	 */
	public function getSound(name:String):Sound {
		var sound = sounds.get(name);
		if (sound == null) {
			for (assets in uiAssetses) {
				sound = assets.getSound(name);
				if (sound != null) {
					return sound;
				}
			}
		}
		return sound;
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

	/**
	 * 获得界面配置
	 * @param name 
	 * @return UIAssets
	 */
	public function getUIAssets(name:String):UIAssets {
		var uiAssets = uiAssetses.get(name);
		if (uiAssets == null) {
			for (assets in uiAssetses) {
				uiAssets = assets.getUIAssets(name);
				if (uiAssets != null) {
					return uiAssets;
				}
			}
		}
		return uiAssets;
	}

	/**
	 * 播放指定音频
	 * @param name 
	 * @return ISoundChannel
	 */
	public function playSound(name:String):ISoundChannel {
		var sound = this.getSound(name);
		if (sound != null) {
			return sound.root.play();
		}
		return null;
	}

	override function errorValue(data:FutureErrorEvent) {
		this.loading = false;
		if (isError)
			return;
		this.isError = true;
		if (__tryLoadTimes++ >= tryLoadTimes) {
			super.errorValue(data);
		} else {
			// 1秒后重试
			Timer.getInstance().setTimeout(() -> {
				trace("Assets: 重试加载 futures.length=", futures.length, __tryLoadTimes);
				this.isError = false;
				this.isComplete = false;
				this.start();
			}, 2);
		}
	}
}
