import hx.utils.Assets;
import hx.displays.DisplayObjectContainer;
import hx.displays.Image;
import hx.displays.Stage;

/**
 * 游戏基础类入口
 */
class Game extends Stage {
	/**
	 * 资源管理器
	 */
	var assets = new Assets();

	override function onInit() {
		super.onInit();
		// 开始加载资源
		assets.loadBitmapData("assets/logo.jpg");
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

		// 容器加图片显示对象
		var box = new DisplayObjectContainer();
		this.addChild(box);
		var image2 = new Image();
		box.addChild(image2);
		this.addChild(box);
	}
}
