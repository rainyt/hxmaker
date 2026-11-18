package hx.assets;

#if (spine_haxe || spine_hx)
import hx.assets.LoadData;
import hx.display.BitmapData;
import hx.events.FutureErrorEvent;
import spine.SkeletonJson;
import spine.attachments.AtlasAttachmentLoader;
#if spine_haxe
import spine.SkeletonBinary;
import spine.atlas.TextureAtlas;
#else
import spine.support.graphics.TextureAtlas;
#end

/** 加载图集及分页贴图，同时准备 JSON、二进制解析器。 */
class SpineTextureAtlasFuture extends Future<SpineTextureAtlas, SpineLoadData> {
	private var _ownedAssets:Array<AssetObject<Dynamic>> = [];
	private var _bitmaps:Map<String, BitmapData> = [];
	private var _pageNames:Array<String> = [];
	private var _atlasText:String;
	private var _started:Bool = false;

	override public function post():Void {
		if (_started) return;
		_started = true;
		var data:SpineLoadData = getLoadData();
		if (data.atlasText != null) {
			beginPages(data.atlasText);
		} else {
			new StringFuture(data.atlas).onComplete(function(asset:AssetObject<String>):Void {
				own(asset);
				beginPages(asset.data);
			}).onError(errorValue);
		}
	}

	private function beginPages(text:String):Void {
		_atlasText = text;
		var data:SpineLoadData = getLoadData();
		if (data.pages != null) {
			for (name in data.pages.keys()) _pageNames.push(name);
		} else _pageNames.push("");
		if (_pageNames.length == 0) {
			errorValue(FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "Spine 图集没有分页贴图"));
			return;
		}
		loadPage(0);
	}

	private function loadPage(index:Int):Void {
		var name:String = _pageNames[index];
		var data:SpineLoadData = getLoadData();
		var path:String = data.pages != null ? data.pages.get(name) : data.png;
		new BitmapDataFuture(path).onComplete(function(asset:AssetObject<BitmapData>):Void {
			own(asset);
			_bitmaps.set(name, asset.data);
			if (index + 1 < _pageNames.length) loadPage(index + 1); else finishAtlas();
		}).onError(errorValue);
	}

	private function finishAtlas():Void {
		var result:SpineTextureAtlas;
		try {
			result = new SpineTextureAtlas(_bitmaps.get(_pageNames[0]), getLoadData().pages != null ? _bitmaps : null);
			var atlas:TextureAtlas = new TextureAtlas(_atlasText, result);
			var loader:AtlasAttachmentLoader = new AtlasAttachmentLoader(atlas);
			result.skeletonJson = new SkeletonJson(loader);
			#if spine_haxe
			result.skeletonBinary = new SkeletonBinary(loader);
			#end
		} catch (error:Dynamic) {
			errorValue(FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "Spine 图集解析失败：" + Std.string(error)));
			return;
		}
		_ownedAssets = [];
		completeValue(result);
	}

	private function own(asset:AssetObject<Dynamic>):Void {
		_ownedAssets.push(asset);
		addAssetObject(asset);
	}

	override public function errorValue(error:FutureErrorEvent):Void {
		if (isError || isComplete) return;
		for (asset in _ownedAssets) asset.release();
		_ownedAssets = [];
		super.errorValue(error);
	}
}

typedef SpineLoadData = {
	png:String,
	atlas:String,
	/** 可选的分页名到贴图路径映射；省略时沿用单贴图加载。 */
	?pages:Map<String, String>,
	/** 已读取的图集文本，可用于组合多个 Unity AtlasAsset。 */
	?atlasText:String
} & LoadData;
#end
