package;

import hx.display.BitmapData;
import hx.display.DisplayObject;
import hx.display.DisplayObjectContainer;
import hx.display.Image;
import hx.geom.Matrix;
import hx.geom.Point;
import hx.geom.Rectangle;
import hx.layout.HorizontalLayout;

/** 不启动引擎的坐标转换回归检查；需要通知用户后另行执行。 */
@:access(hx.display.DisplayObject)
class CoordinateTransformChecks {
	static function check(value:Bool, message:String):Void {
		if (!value) throw message;
	}

	static function point(value:Point, x:Float, y:Float, message:String):Void {
		check(Math.abs(value.x - x) < 0.00001 && Math.abs(value.y - y) < 0.00001, message);
	}

	static function main():Void {
		var root = new DisplayObjectContainer();
		var parent = new DisplayObjectContainer();
		var child = new DisplayObject();
		var unrelated = new TransformProbe();
		root.addChild(parent);
		root.addChild(unrelated);
		parent.addChild(child);
		root.x = 100; root.y = 200;
		parent.x = 10; parent.y = 20; parent.rotation = 90;
		child.x = 3; child.y = 4;
		var input = new Point(2, 5);
		point(child.localToGlobal(input), 101, 225, "首次查询必须刷新尚未渲染的祖先链");
		point(input, 2, 5, "默认输出不能修改输入点");
		check(unrelated.updates == 0, "查询不能更新无关分支的世界矩阵");
		check(root.__transformDirty && parent.__transformDirty && child.__transformDirty, "查询不能消费渲染脏标记");

		var version = child.__worldTransformVersion;
		for (_ in 0...1000)
			child.localToGlobal(input);
		check(child.__worldTransformVersion == version, "重复查询不能反复计算未变化的世界矩阵");
		parent.x = 30;
		point(child.localToGlobal(input), 121, 225, "同一帧内父节点移动必须生效");
		var output = new Point();
		check(child.localToGlobal(input, output) == output, "必须复用提供的输出点");
		check(child.globalToLocal(output, output) == output, "逆变换必须支持原地输出");
		point(output, 2, 5, "旋转下原地正逆变换必须保持原始输入的两个分量");

		var other = new DisplayObjectContainer();
		other.x = -20;
		other.addChild(child);
		point(child.localToGlobal(input), -15, 9, "重新挂载必须更换世界坐标系");
		other.removeChild(child);
		point(child.localToGlobal(input), 5, 9, "移出显示树后必须使用自身变换");
		child.transform.tx = 50;
		point(child.localToGlobal(input), 52, 9, "可修改矩阵的原地修改不能被缓存遗漏");

		root.__updateTransform(root);
		point(root.localToGlobal(new Point()), 100, 200, "以自身作为渲染根时不能叠加自身矩阵");
		parent.addChild(child);
		child.localToGlobal(input);
		parent.__updateTransform(null);
		point(child.localToGlobal(input), 121, 272, "离屏更新后必须恢复真实祖先链");
		parent.alpha = 0.5;
		child.alpha = 0.4;
		child.localToGlobal(input);
		check(Math.abs(child.__worldAlpha - 0.2) < 0.00001, "父透明度变化必须更新后代世界透明度");

		var target = new DisplayObject();
		child.transform = new Matrix(1, 0, 0, 1, 10, 20);
		other.addChild(child);
		child.__rect = new Rectangle(0, 0, 8, 6);
		target.x = 5; target.y = 7;
		var bounds = child.getBounds(target);
		check(bounds.x == -15 && bounds.y == 13 && bounds.width == 8 && bounds.height == 6,
			"相对边界必须同时同步源和目标对象");
		target.x = 15;
		check(child.getBounds(target).x == -25, "仅目标节点变化时也必须更新相对边界");

		var bitmap = new BitmapData();
		bitmap.frameRect = new Rectangle(-5, -7, 20, 30);
		var image = new Image(bitmap);
		image.x = 10; image.y = 20;
		point(image.localToGlobal(new Point()), 15, 27, "图片坐标必须保留图集裁边偏移");
		bitmap.frameRect.x = -8;
		point(image.localToGlobal(new Point()), 18, 27, "裁边数据原地修改必须使缓存失效");
		var replacement = new BitmapData();
		replacement.frameRect = new Rectangle(2, 3, 20, 30);
		image.data = replacement;
		point(image.localToGlobal(new Point()), 8, 17, "替换图片必须更新裁边偏移");

		var row = new DisplayObjectContainer();
		row.layout = new HorizontalLayout();
		var first = new DisplayObject(), second = new DisplayObject();
		first.__rect = new Rectangle(0, 0, 25, 10);
		row.addChild(first); row.addChild(second);
		point(second.localToGlobal(new Point()), 25, 0, "查询必须先结算祖先待处理布局");
		trace("坐标转换回归检查完成");
	}
}

/** 观测无关分支是否被坐标查询误更新。 */
private class TransformProbe extends DisplayObject {
	public var updates:Int = 0;

	override function __updateWorldTransform(parent:DisplayObject):Void {
		updates++;
		super.__updateWorldTransform(parent);
	}
}
