package hx.assets;

#if (spine_haxe || spine_hx)
import spine.SkeletonJson;
import spine.attachments.AtlasAttachmentLoader;
import hx.spine.SpineTypes.TextureAtlas;
import hx.assets.LoadData;
import hx.events.FutureErrorEvent;
import hx.display.BitmapData;

/**
 * Spine纹理图集资源加载
 */
class SpineTextureAtlasFuture extends Future<SpineTextureAtlas, SpineLoadData> {
	override function post():Void {
		super.post();
		new BitmapDataFuture(this.getLoadData().png).onComplete((bitmapData:AssetObject<BitmapData>) -> {
			this.addAssetObject(bitmapData);
			new StringFuture(this.getLoadData().atlas).onComplete((atlasString:AssetObject<String>) -> {
				this.addAssetObject(atlasString);
				// 加载完成，处理精灵图
				var spineTextureAtlas:SpineTextureAtlas;
				try {
					spineTextureAtlas = new SpineTextureAtlas(bitmapData.data);
					var atlas:TextureAtlas = new TextureAtlas(atlasString.data, spineTextureAtlas);
					spineTextureAtlas.skeletonJson = new SkeletonJson(new AtlasAttachmentLoader(atlas));
				} catch (error:Dynamic) {
					errorValue(FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "Spine 图集解析失败：" + Std.string(error)));
					return;
				}
				this.completeValue(spineTextureAtlas);
			}).onError(errorValue);
		}).onError(errorValue);
	}
}

typedef SpineLoadData = {
	png:String,
	atlas:String
} &
	LoadData;
#end
