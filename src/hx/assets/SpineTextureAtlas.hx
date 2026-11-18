package hx.assets;

#if (spine_haxe || spine_hx)
import haxe.io.Bytes;
import hx.display.BitmapData;
import spine.SkeletonData;
import spine.SkeletonJson;
#if spine_hx
import spine.support.graphics.TextureLoader;
import spine.support.graphics.TextureAtlas.AtlasRegion as TextureAtlasRegion;
import spine.support.graphics.TextureAtlas.AtlasPage as TextureAtlasPage;
#else
import spine.SkeletonBinary;
import spine.atlas.TextureAtlasRegion;
import spine.atlas.TextureAtlasPage;
import spine.atlas.TextureLoader;
#end

/**
 * Spine精灵图
 */
class SpineTextureAtlas extends Atlas implements TextureLoader {
	/**
	 * Json格式读取
	 */
	public var skeletonJson:SkeletonJson;

	/**
	 * 二进制格式读取
	 */
	#if spine_haxe
	public var skeletonBinary:SkeletonBinary;
	#end

	private var __regions:Map<String, TextureAtlasRegion> = new Map();
	private var _pages:Map<String, BitmapData>;

	/** 不传分页表时沿用原来的单贴图行为。 */
	public function new(bitmapData:BitmapData, pages:Map<String, BitmapData> = null) {
		super(bitmapData);
		_pages = pages;
	}

	/**
	 * 加载资源
	 * @param page 
	 * @param path 
	 */
	public function loadPage(page:TextureAtlasPage, path:String) {
		var bitmap:BitmapData = _pages != null ? _pages.get(path) : this.bitmapData;
		if (bitmap == null) throw "Spine 图集缺少分页贴图：" + path;
		#if spine_haxe
		page.texture = bitmap;
		#else
		page.rendererObject = bitmap;
		#end
		page.width = bitmap.data.getWidth();
		page.height = bitmap.data.getHeight();
	}

	/**
	 * 卸载资源
	 * @param page 
	 */
	public function unloadPage(page:TextureAtlasPage) {}

	public function getRegionByName(name:String):TextureAtlasRegion {
		return __regions.get(name);
	}

	public function loadRegion(region:TextureAtlasRegion):Void {
		#if spine_haxe
		region.texture = region.page.texture;
		#else
		region.rendererObject = region.page.rendererObject;
		#end
		__regions.set(region.name, region);
	}

	/**
	 * 根据动画数据创建skeletonData
	 * @param object 
	 */
	public function createSkeletonData(object:Dynamic, scale:Float = 1):SkeletonData {
		#if spine_haxe
		// 二进制必须优先按数据类型分流，不能因为 JSON 解析器存在就把 Bytes 当 JSON。
		if (Std.isOfType(object, Bytes)) {
			if (skeletonBinary == null) throw "Spine 图集未初始化二进制解析器";
			skeletonBinary.scale = scale;
			return skeletonBinary.readSkeletonData(cast object);
		}
		if (skeletonJson != null) {
			skeletonJson.scale = scale;
			return skeletonJson.readSkeletonData(object);
		} else if (skeletonBinary != null) {
			skeletonBinary.scale = scale;
			return skeletonBinary.readSkeletonData(object);
		}
		#else
		if (Std.isOfType(object, Bytes)) throw "当前 Spine 运行库不支持二进制骨骼，请使用 spine-haxe";
		if (skeletonJson != null) {
			skeletonJson.setScale(scale);
			return skeletonJson.readSkeletonData(new SkeletonDataFileHandle(null, object));
		}
		#end
		return null;
	}
}

#if spine_hx
class SkeletonDataFileHandle implements spine.support.files.FileHandle {
	public var path:String = "";

	private var _data:String;

	public function new(path:String, data:String = null) {
		this.path = path;
		if (this.path == null)
			this.path = "";
		_data = data;
	}

	public function getContent():String {
		return _data;
	}
}
#end
#end
