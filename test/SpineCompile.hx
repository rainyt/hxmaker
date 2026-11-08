package;

import hx.assets.Assets;
import hx.assets.SpineTextureAtlas;
import hx.display.ISpine;
import hx.display.Quad;
import hx.display.Spine;
import hx.display.SpineSprite;
import hx.events.Event;
import hx.events.SpineEvent;
import hx.spine.SpineTypes.TrackEntry;
import spine.SkeletonData;

/** 双库共用的编译入口；仅做类型检查，不创建需要有效资源的对象。 */
class SpineCompile {
	static function main():Void {
		var check:SkeletonData->Void = checkApi;
		var atlasType:Class<SpineTextureAtlas> = SpineTextureAtlas;
		trace(Spine.runtimeName);
	}

	/** 强制编译公共接口、插槽、事件及资源调用链，供两套 HXML 共同使用。 */
	private static function checkApi(data:SkeletonData):Void {
		var display:Spine = new Spine(data);
		var api:ISpine = display;
		var entry:TrackEntry = api.play("walk", 0, true);
		api.setSkinByName("default");
		api.renderFps = 30;
		api.update(0);
		display.addEventListener(Event.COMPLETE, (event:SpineEvent) -> trace(event.trackEntry));
		display.addEventListener(SpineEvent.EVENT, (event:SpineEvent) -> trace(event.event));
		display.stop();
		var sprite:SpineSprite = new SpineSprite(data);
		sprite.bindSlot("head", new Quad(10, 10, 0xffffff));
		sprite.play("walk");
		sprite.update(0);
		sprite.stop();
		sprite.dispose();
		display.dispose();
		var assets:Assets = new Assets();
		assets.loadSpineAtlas("character.png", "character.atlas");
		assets.loadString("character.json");
		var skeletonData:SkeletonData = assets.getSkeletonData("character");
	}
}
