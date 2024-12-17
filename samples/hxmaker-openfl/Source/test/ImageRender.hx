package test;

import hx.displays.Quad;
import hx.displays.TextFormat;
import hx.displays.Label;
import hx.events.Event;
import hx.displays.Image;
import hx.utils.Assets;
import hx.displays.Scene;
import hx.displays.DisplayObjectContainer;

/**
 * 测试图片渲染
 */
class ImageRender extends Scene {
	/**
	 * 资源管理器
	 */
	var assets = new Assets();

	override function onAddToStage() {
		super.onAddToStage();
		// 开始加载资源
		assets.loadBitmapData("assets/logo.jpg");
		assets.loadBitmapData("assets/wabbit_alpha.png");
		assets.loadAtlas("assets/EmojAtlas.png", "assets/EmojAtlas.xml");
		assets.onComplete((data) -> {
			this.onLoaded();
		}).onError(err -> {
			trace("加载失败");
		});
		assets.start();
	}

	/**
	 * 当资源加载完成时
	 */
	public function onLoaded():Void {
		trace("加载完成");
		// 显示一张图片
		var image:Image = new Image(assets.bitmapDatas.get("logo"));
		this.addChild(image);
		image.x = 500;
		image.y = 500;
		image.scaleX = 1;
		image.rotation = 75;

		trace("图片矩阵", image.width, image.height, image.getBounds());
		

		// 容器加图片显示对象
		var box = new DisplayObjectContainer();
		this.addChild(box);
		var image2 = new Image(assets.bitmapDatas.get("logo"));
		box.addChild(image2);
		this.addChild(box);
		box.x = 300;
		box.y = 300;

		for (ix in 0...100) {
			for (iy in 0...100) {
				var image3 = new Image(assets.bitmapDatas.get("logo"));
				box.addChild(image3);
				image3.x = ix * 200;
				image3.y = iy * 200;
			}
		}

		this.addEventListener(Event.UPDATE, (e) -> {
			box.rotation++;
		});

		box.mouseEnabled = false;

		var tuzi = new Image(assets.bitmapDatas.get("wabbit_alpha"));
		this.addChild(tuzi);

		var images = [];
		for (i in 0...100) {
			var image3 = new Image(assets.bitmapDatas.get("logo"));
			this.addChild(image3);
			image3.x = Math.random() * 500;
			image3.y = Math.random() * 500;
			images.push(image3);
		}

		this.addEventListener(Event.UPDATE, (e:Event) -> {
			for (image in images) {
				image.x += 5;
				image.y += 3;
				image.rotation += Math.random() * 10;
				if (image.x > 500) {
					image.x = 0;
				}
				if (image.y > 500) {
					image.y = 0;
				}
			}
		});

		var emojs = [];

		for (_ => value in assets.atlases.get("EmojAtlas").bitmapDatas) {
			var atlasImage = new Image(value);
			this.addChild(atlasImage);
			atlasImage.x = Math.random() * stage.stageWidth;
			atlasImage.y = Math.random() * stage.stageHeight;
			emojs.push(atlasImage);
		}

		var img = new Image(assets.atlases.get("EmojAtlas").bitmapDatas.get("zw_5"));
		this.addChild(img);
		img.x = img.y = 100;
		emojs.push(img);

		// for (image in emojs) {
		// 	var rect = image.getBounds();
		// 	trace("矩阵", rect);
		// 	// 矩形渲染
		// 	var quad = new Quad(400, 50, Std.random(0xffffff));
		// 	this.addChild(quad);
		// 	quad.x = rect.x;
		// 	quad.y = rect.y;
		// 	quad.width = rect.width;
		// 	quad.height = rect.height;
		// 	quad.alpha = 0.3;
		// }

		// 矩形渲染
		var quad = new Quad(400, 50, 0xffff00);
		this.addChild(quad);
		quad.y = 400;
	}
}