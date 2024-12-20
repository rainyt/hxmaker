package hx.utils.atlas;

import spine.SkeletonData;
import spine.SkeletonBinary;
import spine.SkeletonJson;
import spine.atlas.TextureAtlasRegion;
import spine.atlas.TextureAtlasPage;
import spine.atlas.TextureLoader;

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
	public var skeletonBinary:SkeletonBinary;

	private var __regions:Map<String, TextureAtlasRegion> = new Map();

	/**
	 * 加载资源
	 * @param page 
	 * @param path 
	 */
	public function loadPage(page:TextureAtlasPage, path:String) {
		page.texture = this.bitmapData;
		page.width = this.bitmapData.data.getWidth();
		page.height = this.bitmapData.data.getHeight();
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
		region.texture = this.bitmapData;
		__regions.set(region.name, region);
	}

	/**
	 * 根据动画数据创建skeletonData
	 * @param object 
	 */
	public function createSkeletonData(object:Dynamic):SkeletonData {
		if (skeletonJson != null) {
			return skeletonJson.readSkeletonData(object);
		} else if (skeletonBinary != null) {
			return skeletonBinary.readSkeletonData(object);
		}
		return null;
	}
}

// @:keep
// class BitmapDataTextureLoader implements TextureLoader {
// 	private var _bitmapData:Map<String, BitmapData>;
// 	private var _regions:Map<String, TextureAtlasRegion> = [];
// 	public function new(bitmapData:Map<String, BitmapData>) {
// 		this._bitmapData = bitmapData;
// 	}
// 	public function loadPage(page:TextureAtlasPage, path:String):Void {
// 		var bitmapData:BitmapData = this._bitmapData.get(StringUtils.getName(path));
// 		if (bitmapData == null)
// 			throw("BitmapData not found with name: " + path);
// 		page.texture = bitmapData;
// 		page.width = bitmapData.width;
// 		page.height = bitmapData.height;
// 	}
// 	public function getRegionByName(name:String):TextureAtlasRegion {
// 		return _regions.get(name);
// 	}
// 	public function loadRegion(region:TextureAtlasRegion):Void {
// 		_regions.set(region.name, region);
// 	}
// 	public function unloadPage(page:TextureAtlasPage):Void {
// 		page.texture.dispose();
// 	}
// }
