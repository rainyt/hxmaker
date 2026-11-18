package;

import hx.display.Box;
import hx.display.Quad;
import hx.display.Stage;
import hx.geom.Point;

/**
 * 变换查询回归检查。
 * 验证舞台干净时不重复刷新整棵树，且变换、边界和子节点变更仍能得到最新结果。
 */
@:access(hx.display.DisplayObject)
class TransformQueryCheck {
	static function check(value:Bool, message:String):Void {
		if (!value)
			throw message;
	}

	static function closeEnough(actual:Float, expected:Float, message:String):Void {
		check(Math.abs(actual - expected) < 0.0001, message + "，实际值=" + actual + "，期望值=" + expected);
	}

	static function main():Void {
		var stage:Stage = new Stage();
		stage.__stageWidth = 800;
		stage.__stageHeight = 600;

		var parent:Box = new Box();
		parent.x = 100;
		parent.y = 50;
		parent.scaleX = 2;
		parent.scaleY = 3;
		stage.addChild(parent);

		var child:Quad = new Quad(20, 10, 0xffffff);
		child.x = 4;
		child.y = 5;
		parent.addChild(child);

		stage.__updateTransform(null);
		stage.__dirty = false;

		var global:Point = child.localToGlobal(new Point(0, 0));
		closeEnough(global.x, 108, "首次本地转世界坐标的 X");
		closeEnough(global.y, 65, "首次本地转世界坐标的 Y");
		check(!stage.__dirty, "干净舞台上的坐标查询不重新标脏舞台");

		var bounds = child.getBounds(stage);
		closeEnough(bounds.x, 108, "干净舞台上的边界 X");
		closeEnough(bounds.y, 65, "干净舞台上的边界 Y");
		closeEnough(bounds.width, 40, "缩放后的边界宽度");
		closeEnough(bounds.height, 30, "缩放后的边界高度");

		parent.x = 120;
		check(stage.__dirty, "父级变换变化使舞台变脏");
		global = child.localToGlobal(new Point(0, 0));
		closeEnough(global.x, 128, "父级变换变化后的世界坐标 X");
		closeEnough(global.y, 65, "父级变换变化后的世界坐标 Y");
		stage.__dirty = false;
		check(!stage.__dirty, "渲染完成后可复用已更新的世界矩阵");

		parent.scaleX = -2;
		global = child.localToGlobal(new Point(0, 0));
		closeEnough(global.x, 112, "负缩放后的世界坐标 X");
		closeEnough(global.y, 65, "负缩放后的世界坐标 Y");
		var local:Point = child.globalToLocal(global);
		closeEnough(local.x, 0, "负缩放后的世界转本地 X");
		closeEnough(local.y, 0, "负缩放后的世界转本地 Y");

		parent.removeChild(child);
		check(stage.__dirty, "移除子节点使舞台变脏");
		stage.__updateTransform(null);
		stage.__dirty = false;
		parent.addChild(child);
		global = child.localToGlobal(new Point(0, 0));
		closeEnough(global.x, 112, "重新挂载后的世界坐标 X");
		closeEnough(global.y, 65, "重新挂载后的世界坐标 Y");

		stage.dispose();
		trace("变换查询回归检查完成");
	}
}
