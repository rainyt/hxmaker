package test;

import hx.events.Event;
import hx.displays.Image;
import hx.utils.Assets;
import hx.displays.Scene;

class WabbitRender extends Scene {
	/**
	 * 资源管理器
	 */
	var assets = new Assets();

	override function onStageInit() {
		super.onStageInit();
		for (i in 0...6) {
			assets.loadBitmapData("assets/wabbit_alpha_" + (i + 1) + ".png");
		}
		assets.onComplete((data) -> {
			this.onLoaded();
		}).onError(err -> {
			trace("加载失败");
		});
		assets.start();
	}

	public function onLoaded():Void {
		var bunnys = [];
		for (i in 0...1000) {
			var bunny = new Bunny(assets.bitmapDatas.get("wabbit_alpha_" + (Std.random(6) + 1)));
			this.addChild(bunny);
			bunny.x = Math.random() * this.stage.stageWidth;
			bunny.y = Math.random() * this.stage.stageHeight;
			bunny.speedX = Math.random() * 5;
			bunny.speedY = (Math.random() * 5) - 2.5;
			bunnys.push(bunny);
		}
		var gravity = 0.5;
		this.addEventListener(Event.UPDATE, (e) -> {
			for (bunny in bunnys) {
				bunny.x += bunny.speedX;
				bunny.y += bunny.speedY;
				bunny.speedY += gravity;
				if (bunny.x > stage.stageWidth) {
					bunny.speedX *= -1;
					bunny.x = stage.stageWidth;
				} else if (bunny.x < 0) {
					bunny.speedX *= -1;
					bunny.x = 0;
				}

				if (bunny.y > stage.stageHeight) {
					bunny.speedY *= -0.8;
					bunny.y = stage.stageHeight;

					if (Math.random() > 0.5) {
						bunny.speedY -= 3 + Math.random() * 4;
					}
				} else if (bunny.y < 0) {
					bunny.speedY = 0;
					bunny.y = 0;
				}
			}
		});
	}
}

/**
 * 兔子
 */
class Bunny extends Image {
	public var speedX:Float = 1;
	public var speedY:Float = 1;
}
