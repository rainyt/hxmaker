package hx.assets;

import spine.SkeletonJson;
import spine.attachments.AtlasAttachmentLoader;
#if spine_haxe
import spine.atlas.TextureAtlas;
#else
import spine.support.graphics.TextureAtlas;
#end
import hx.assets.LoadData;

/**
 * Spine纹理图集资源加载
 */
class SpineTextureAtlasFuture extends Future<SpineTextureAtlas, SpineLoadData> {
	override function post() {
		super.post();
		new BitmapDataFuture(this.getLoadData().png).onComplete((bitmapData) -> {
			new StringFuture(this.getLoadData().atlas).onComplete((atlasString) -> {
				// 加成完成，处理精灵图
				var spineTextureAtlas = new SpineTextureAtlas(bitmapData);
				var atlas:TextureAtlas = new TextureAtlas(atlasString, spineTextureAtlas);
				spineTextureAtlas.skeletonJson = new SkeletonJson(new AtlasAttachmentLoader(atlas));
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
