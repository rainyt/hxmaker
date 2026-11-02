package;

import hx.display.Box;
import hx.display.BoxContainer;
import hx.display.DisplayObject;
import hx.display.DisplayObjectContainer;
import hx.display.Quad;
import hx.geom.Point;
import hx.layout.AnchorLayout;
import hx.layout.AnchorLayoutData;
import hx.layout.Layout;

/** 布局重复计算与同帧失效回归检查；按用户要求暂不执行。 */
@:access(hx.display.DisplayObject)
@:access(hx.display.DisplayObjectContainer)
class LayoutRefreshChecks {
	private static function check(value:Bool, message:String):Void {
		if (!value)
			throw message;
	}

	private static function main():Void {
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
		for (_ in 0...100)
			leaf.localToGlobal(new Point());
		check(root.layouts == 1 && child.layouts == 1 && leaf.layouts == 1, "重复坐标查询不再次布局");
		root.updateLayout();
		check(root.layouts == 2 && child.layouts == 2 && leaf.layouts == 2, "公开刷新仍调用整棵子树的重写方法");
		root.width = 400;
		root.height = 300;
		leaf.localToGlobal(new Point());
		check(root.layouts == 2 && child.layouts == 2 && leaf.layouts == 2, "重复尺寸赋值不制造布局失效");
		root.width = 800;
		leaf.localToGlobal(new Point());
		check(child.width == 800 && leaf.width == 800, "同帧祖先变宽后坐标查询先结算百分比布局");
		root.width = 600;
		leaf.localToGlobal(new Point());
		check(leaf.width == 600, "同帧第二次尺寸修改也必须生效");

		var container:BoxContainer = new BoxContainer();
		container.width = 120;
		container.height = 80;
		container.layout = new AnchorLayout();
		var inside:LayoutProbe = new LayoutProbe();
		inside.layoutData = AnchorLayoutData.fill();
		container.addChild(inside);
		root.addChild(container);
		root.__updateLayout();
		var layouts:Int = inside.layouts;
		inside.localToGlobal(new Point());
		check(!container.box.__layoutDirty && inside.layouts == layouts, "BoxContainer 的内部容器不留下重复布局");

		var state:DisplayObject = new DisplayObject();
		state.width = 10;
		state.height = 20;
		var version:Int = state.__changeVersion;
		state.x = 0;
		state.y = 0;
		state.width = 10;
		state.height = 20;
		check(state.__changeVersion == version, "重复位置和明确尺寸赋值不改变状态版本");
		state.scaleX = 2;
		state.width = 10;
		check(state.scaleX == 1, "相同尺寸仍恢复 setter 原有的缩放语义");
		state.setDirty(false);
		version = state.__changeVersion;
		state.setDirty(false);
		check(state.__changeVersion == version, "渲染消费脏标记不改变依赖版本");
		var automatic:Box = new Box();
		automatic.width = automatic.width;
		check(automatic.__width != null && automatic.__layoutDirty, "自动尺寸首次转明确尺寸不能被跳过");
		var quad:Quad = new Quad(10, 20);
		version = quad.__changeVersion;
		quad.width = 10;
		quad.height = 20;
		check(quad.__changeVersion == version, "重复色块尺寸不触发几何重建");

		var changing:LayoutProbe = new LayoutProbe();
		var layout:InvalidatingLayout = new InvalidatingLayout();
		changing.width = 100;
		changing.layout = layout;
		changing.__updateLayout();
		check(layout.calls == 1 && changing.__layoutDirty, "布局期间的新尺寸失效不能被清空或重入消费");
		changing.__updateLayout();
		check(layout.calls == 2 && !changing.__layoutDirty, "后续查询消费布局期间新增的失效");
		var failing:LayoutProbe = new LayoutProbe();
		failing.width = 100;
		failing.layout = new FailingLayout();
		var failed:Bool = false;
		try failing.__updateLayout() catch (error:Dynamic) failed = true;
		check(failed && failing.__layoutDirty && !failing.__updatingLayout, "异常后恢复失效与重入保护状态");
		failing.__updateLayout();
		check(!failing.__layoutDirty && !failing.__updatingLayout, "异常后允许重新布局");
		trace("布局刷新回归检查完成");
	}
}

/** 用实际的重写方法统计布局次数。 */
private class LayoutProbe extends Box {
	public var layouts:Int = 0;

	override public function updateLayout():Void {
		layouts++;
		super.updateLayout();
	}
}

/** 布局中修改真实尺寸并查询坐标，验证新失效保留和重入保护。 */
private class InvalidatingLayout extends Layout {
	public var calls:Int = 0;

	override public function update(children:Array<DisplayObject>):Void {
		calls++;
		if (calls == 1) {
			parent.width += 1;
			parent.localToGlobal(new Point());
		}
	}
}

private class FailingLayout extends Layout {
	private var failed:Bool = false;

	override public function update(children:Array<DisplayObject>):Void {
		if (!failed) {
			failed = true;
			throw "模拟布局异常";
		}
	}
}
