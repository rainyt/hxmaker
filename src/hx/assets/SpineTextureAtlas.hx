package hx.assets;

#if (spine_haxe || spine_hx)
import spine.SkeletonData;
import spine.SkeletonJson;
import hx.spine.SpineTypes.TextureLoader;
import hx.spine.SpineTypes.TextureAtlasRegion;
import hx.spine.SpineTypes.TextureAtlasPage;
#if spine_haxe
import spine.SkeletonBinary;
#end

/**
 * Spine精灵图
 */
@:build(hx.macro.SpineMacro.build())
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
	public function loadPage(page:TextureAtlasPage, path:String):Void {
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
	public function unloadPage(page:TextureAtlasPage):Void {}

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
		if (skeletonJson != null) {
			var json:String = Std.isOfType(object, String) ? cast object : haxe.Json.stringify(object);
			var root:Dynamic = haxe.Json.parse(json);
			var skeletonInfo:Dynamic = Reflect.field(root, "skeleton");
			var version:String = skeletonInfo == null ? null : Reflect.field(skeletonInfo, "spine");
			var expected:String = #if spine_hx "3.8" #else "4.2" #end;
			if (version != null && version != expected && !StringTools.startsWith(version, expected + "."))
				throw "Spine 数据版本 " + version + " 与当前运行时 " + expected + " 不匹配";
			#if spine_haxe
			return skeletonJson.readSkeletonData(json);
			#else
			return skeletonJson.readSkeletonData(new SkeletonDataFileHandle("skeleton.json", json));
			#end
		}
		#if spine_haxe
		if (skeletonBinary != null)
			return skeletonBinary.readSkeletonData(object);
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
