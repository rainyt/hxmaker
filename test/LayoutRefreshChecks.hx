package;

import hx.display.Box;
import hx.display.BoxContainer;
import hx.display.DisplayObject;
import hx.display.DisplayObjectContainer;
import hx.layout.AnchorLayout;
import hx.layout.AnchorLayoutData;
import hx.layout.Layout;

/**
 * 布局重入与重复失效回归检查。
 * 用于验证从 main 移植的布局性能优化没有改变原有布局结果。
 */
@:access(hx.display.DisplayObject)
@:access(hx.display.DisplayObjectContainer)
class LayoutRefreshChecks {
	static function check(value:Bool, message:String):Void {
		if (!value)
			throw message;
	}

	static function main():Void {
		var root:LayoutProbe = new LayoutProbe();
		var child:LayoutProbe = new LayoutProbe();
		var leaf:LayoutProbe = new LayoutProbe();
		root.width = 400;
		root.height = 300;
		root.layout = new AnchorLayout();
		child.layout = new AnchorLayout();
		child.layoutData = AnchorLayoutData.fill();
		leaf.layoutData = AnchorLayoutData.fill();
		root.addChild(child);
		child.addChild(leaf);

		root.__updateLayout();
		check(root.layouts == 1 && child.layouts == 1 && leaf.layouts == 1, "首次递归每个容器只布局一次");
		check(!root.__layoutDirty && !child.__layoutDirty && !leaf.__layoutDirty, "递归布局消费所有子容器的既有失效");

		root.__updateLayout();
		check(root.layouts == 1 && child.layouts == 1 && leaf.layouts == 1, "没有失效时不重复布局");

		root.width = 400;
		root.height = 300;
		root.__updateLayout();
		check(root.layouts == 1 && child.layouts == 1, "重复尺寸赋值不制造布局失效");

		root.width = 800;
		root.__updateLayout();
		check(child.width == 800 && leaf.width == 800, "祖先变宽后百分比布局生效");

		// 公开刷新仍强制刷新整棵子树，保持原有 updateLayout 语义
		root.updateLayout();
		check(root.layouts == 3 && child.layouts == 3 && leaf.layouts == 3, "公开 updateLayout 仍刷新整棵子树");

		// 布局过程中的新失效必须保留给下一次结算，且不能在本次重入消费
		var changing:LayoutProbe = new LayoutProbe();
		var invalidating:InvalidatingLayout = new InvalidatingLayout();
		changing.width = 100;
		changing.layout = invalidating;
		changing.__updateLayout();
		check(invalidating.calls == 1 && changing.__layoutDirty, "布局期间的新失效不能被清空");
		changing.__updateLayout();
		check(invalidating.calls == 2 && !changing.__layoutDirty, "后续查询消费布局期间新增的失效");

		// 布局抛异常后要恢复失效与重入状态
		var failing:LayoutProbe = new LayoutProbe();
		failing.width = 100;
		failing.layout = new FailingLayout();
		var failed:Bool = false;
		try {
			failing.__updateLayout();
		} catch (error:Dynamic) {
			failed = true;
		}
		check(failed && failing.__layoutDirty && !failing.__updatingLayout, "布局异常后恢复失效与重入状态");
		failing.__updateLayout();
		check(!failing.__layoutDirty && !failing.__updatingLayout, "异常后允许重新布局");

		// BoxContainer 内部 box 的脏标记必须被消费，避免后续重复布局
		var container:BoxContainer = new BoxContainer();
		container.width = 120;
		container.height = 80;
		container.layout = new AnchorLayout();
		var inside:LayoutProbe = new LayoutProbe();
		inside.layoutData = AnchorLayoutData.fill();
		container.addChild(inside);
		container.__updateLayout();
		check(inside.width == 120, "BoxContainer 内部布局生效");
		check(!container.box.__layoutDirty, "BoxContainer 内部 box 不留下重复布局");

		trace("布局重入与重复失效检查完成");
	}
}

/** 统计 updateLayout 实际执行次数。 */
private class LayoutProbe extends Box {
	public var layouts:Int = 0;

	override public function updateLayout():Void {
		layouts++;
		super.updateLayout();
	}
}

/** 布局期间修改父容器尺寸并模拟坐标查询重入。 */
private class InvalidatingLayout extends Layout {
	public var calls:Int = 0;

	override public function update(children:Array<DisplayObject>):Void {
		calls++;
		if (calls == 1) {
			parent.width += 1;
			@:privateAccess cast(parent, DisplayObjectContainer).__updateLayout();
		}
	}
}

/** 首次布局抛异常，用于验证状态恢复。 */
private class FailingLayout extends Layout {
	private var failed:Bool = false;

	override public function update(children:Array<DisplayObject>):Void {
		if (!failed) {
			failed = true;
			throw "模拟布局异常";
		}
	}
}
