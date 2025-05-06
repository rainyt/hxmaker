package hx.assets;

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

	/**
	 * 加载资源
	 * @param page 
	 * @param path 
	 */
	public function loadPage(page:TextureAtlasPage, path:String) {
		#if spine_haxe
		page.texture = this.bitmapData;
		#else
		page.rendererObject = this.bitmapData;
		#end
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
		#if spine_haxe
		region.texture = this.bitmapData;
		#else
		region.rendererObject = this.bitmapData;
		#end
		__regions.set(region.name, region);
	}

	/**
	 * 根据动画数据创建skeletonData
	 * @param object 
	 */
	public function createSkeletonData(object:Dynamic):SkeletonData {
		#if spine_haxe
		if (skeletonJson != null) {
			return skeletonJson.readSkeletonData(object);
		} else if (skeletonBinary != null) {
			return skeletonBinary.readSkeletonData(object);
		}
		#else
		if (skeletonJson != null) {
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
