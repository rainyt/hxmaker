package;

import hx.core.Hxmaker;
import hx.core.Render;
import hx.display.BitmapData;
import hx.display.Box;
import hx.display.CustomDisplayObject;
import hx.display.Image;
import hx.geom.Point;
import hx.geom.Rectangle;
import hx.render.ImageBufferData;
import hx.shader.MultiTextureShader;
import IncrementalBufferCheck.FakeBitmap;

/** 验证世界矩阵缓存更新后，依赖渲染脏标记的后端对象也能刷新。 */
@:access(hx.core.Hxmaker)
@:access(hx.display.DisplayObject)
@:access(hx.display.Image)
@:access(hx.shader.MultiTextureShader)
class WorldTransformBridgeCheck {
	private static var checks:Int = 0;
	private static function check(value:Bool, message:String):Void {
		checks++;
		if (!value) throw message;
	}

	private static function main():Void {
		Hxmaker.__engine = cast {dt:0.016};
		MultiTextureShader.__supportedMultiTextureUnits = 3;
		var renderer:BridgeRender = BridgeRender.create();
		var parent:Box = new Box();
		var native:openfl.display.Sprite = new openfl.display.Sprite();
		var custom:CustomDisplayObject = new CustomDisplayObject(native);
		custom.x = 7; parent.x = 10; parent.addChild(custom);
		parent.__updateTransform(null);
		renderer.renderDisplayObject(custom);
		check(native.transform.matrix.tx == 17, "自定义对象首次同步世界矩阵");
		parent.x = 30;
		var position:Point = custom.localToGlobal(new Point());
		check(position.x == 37, "坐标查询提前刷新祖先和当前节点");
		renderer.renderDisplayObject(custom);
		check(native.transform.matrix.tx == 37, "坐标查询后渲染仍同步父级变换");
		check(!custom.__consumeWorldTransformChanged(), "后端消费世界变化通知");
		renderer.renderDisplayObject(custom);
		check(!custom.__transformDirty, "静止帧不重复标记自定义对象变换");

		for (repeatMode in [false, true]) {
			var data:BitmapData = BitmapData.formData(new FakeBitmap(24, 24));
			var image:Image = new Image(data);
			if (repeatMode) image.repeat = true; else image.scale9Grid = new Rectangle(4, 4, 16, 16);
			image.width = 48; image.height = 48; image.x = 5;
			var container:Box = new Box(); container.x = 10; container.addChild(image);
			container.__updateTransform(null);
			renderer.begin(); renderer.renderDisplayObject(image);
			check(image.getGraphic().__worldTransform.tx == 15, "图形首次计算父级位置");
			container.x = 40;
			image.localToGlobal(new Point());
			renderer.begin(); renderer.renderDisplayObject(image);
			check(image.getGraphic().__worldTransform.tx == 45, "九宫格或repeat跟随父级移动");
			container.alpha = 0.5;
			container.__updateTransform(null);
			renderer.begin(); renderer.renderDisplayObject(image);
			check(image.getGraphic().__worldAlpha == 0.5, "九宫格或repeat跟随父级透明度");
		}
		trace("世界矩阵与后端刷新衔接通过：" + checks + " 项断言");
	}
}

/** 不创建 GPU shader，保留真实自定义对象与图形绘制控制流。 */
@:access(hx.core.Render)
class BridgeRender extends Render {
	public static function create():BridgeRender {
		var renderer:BridgeRender = Type.createEmptyInstance(BridgeRender);
		renderer.incrementalBufferEnabled = true;
		renderer.__incrementalSuppressed = false;
		renderer.__cacheAsBitmap = false;
		renderer.__stage = new openfl.display.Sprite();
		renderer.imageBufferData = [];
		renderer.begin();
		return renderer;
	}
	public function begin():Void { drawImageBuffDataIndex = 0; createImageBufferData(0); }
	override public function endFillImageDataBuffer():openfl.display.Sprite return null;
	override public function renderImageBuffData(data:ImageBufferData):openfl.display.Sprite {
		data.endFill(); drawImageBuffDataIndex++; createImageBufferData(drawImageBuffDataIndex); return null;
	}
}
