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
	}
}
