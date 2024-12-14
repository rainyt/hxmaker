import hx.displays.DisplayObjectContainer;
import hx.displays.Image;
import hx.displays.Stage;

/**
 * 游戏基础类入口
 */
class Game extends Stage {
	override function onInit() {
		super.onInit();
		// 显示一张图片
		var image:Image = new Image();
		this.addChild(image);

		// 容器加图片显示对象
		var box = new DisplayObjectContainer();
		this.addChild(box);
		var image2 = new Image();
		box.addChild(image2);
		this.addChild(box);
	}
}
