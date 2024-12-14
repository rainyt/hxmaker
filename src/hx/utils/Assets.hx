package hx.utils;

import haxe.io.Path;
import hx.displays.BitmapData;

/**
 * 资源管理器
 */
class Assets extends Future<Assets> {
	/**
	 * 正在加载的资源管理器
	 */
	private static var __assets:Array<Assets> = [];

	/**
	 * 重新再请求加载下一个
	 */
	private static function readyLoadNext():Void {
		var asset:Assets = __assets.shift();
		if (asset != null) {
			asset.loadNext();
		}
	}

	/**
	 * 对路径进行格式化
	 * @param path 
	 * @return String
	 */
	public static function formatName(path:String):String {
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
	public var futures:Array<Future<Dynamic>> = [];

	/**
	 * 位图列表
	 */
	public var bitmapDatas:Map<String, BitmapData> = new Map();

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
	 * 加载位图资源
	 * @param path 
	 * @return Future<BitmapData>
	 */
	public function loadBitmapData(path:String) {
		pushFuture(new hx.core.BitmapDataFuture(path, false));
	}

	/**
	 * 追加到加载队列
	 * @param future 
	 */
	public function pushFuture(future:Future<Dynamic>) {
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
		loading = true;
		this.totalCounts = futures.length;
		this.loadedCounts = 0;
		loadNext();
	}

	/**
	 * 停止加载
	 */
	public function stop():Void {
		// TODO 这里应该停止所有加载流程
	}

	/**
	 * 准备加载下一个
	 */
	private function loadNext():Void {
		var future = futures[__loadIndex];
		if (future == null) {
			return;
		}
		if (CURRENT_LOAD_COUNTS < MAX_ASSETS_LOAD_COUNTS) {
			CURRENT_LOAD_COUNTS++;
			future.post();
			__loadIndex++;
		}
	}

	/**
	 * 加成完成时触发
	 * @param future 
	 */
	private function __onCompleted(future:Future<Dynamic>, data:Dynamic):Void {
		CURRENT_LOAD_COUNTS--;
		loadedCounts++;
		if (data is BitmapData) {
			bitmapDatas.set(formatName(future.getLoadData()), data);
		}
		if (loadedCounts == totalCounts) {
			this.completeValue(this);
			__assets.remove(this);
		}
		readyLoadNext();
	}

	/**
	 * 加载失败时触发
	 * @param future 
	 */
	private function __onError(future:Dynamic):Void {
		CURRENT_LOAD_COUNTS--;
		readyLoadNext();
	}
}
