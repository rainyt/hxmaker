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
import hx.layout.HorizontalLayout;

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
		checkDynamicLayout();
		checkLayoutParticipation();
		checkLayoutDataDuringUpdate();
		trace("布局刷新回归检查完成");
	}

	/** 模拟编辑器在窗口尺寸不变时切换工具栏、侧栏和画布锚点。 */
	private static function checkDynamicLayout():Void {
		var root:LayoutProbe = new LayoutProbe();
		var child:LayoutProbe = new LayoutProbe();
		root.width = 400;
		root.height = 300;
		root.layout = new AnchorLayout();
		child.layoutData = AnchorLayoutData.fill();
		root.addChild(child);
		root.__updateLayout();
		var layouts:Int = root.layouts;
		var data:AnchorLayoutData = new AnchorLayoutData(64, 80, 20, 40);
		child.layoutData = data;
		check(root.__layoutDirty, "替换锚点数据让父容器布局失效");
		var point:Point = child.localToGlobal(new Point());
		check(point.x == 40 && point.y == 64 && child.width == 280 && child.height == 216,
			"尺寸不变时替换锚点，同帧坐标查询应用新位置和拉伸尺寸");
		check(root.layouts == layouts + 1 && !root.__layoutDirty, "动态锚点只触发一次父布局");
		layouts = root.layouts;
		root.layout = root.layout;
		child.localToGlobal(new Point());
		check(root.layouts == layouts, "重复赋值相同布局策略不产生新失效");
		data.left = 60;
		child.layoutData = data;
		point = child.localToGlobal(new Point());
		check(point.x == 60 && child.width == 260, "原地修改锚点后重新赋值同一引用仍触发布局");
		data.top = 72;
		root.invalidateLayout();
		check(child.localToGlobal(new Point()).y == 72, "原地修改锚点后也可显式请求布局");
		child.left = 70;
		child.right = 90;
		child.top = 80;
		child.bottom = 30;
		point = child.localToGlobal(new Point());
		check(point.x == 70 && point.y == 80 && child.width == 240 && child.height == 190,
			"直接修改四边距属性自动更新父布局");
		child.left = child.right = child.top = child.bottom = null;
		child.centerX = 10;
		child.centerY = 20;
		point = child.localToGlobal(new Point());
		check(point.x == 90 && point.y == 75, "直接修改中心锚点属性自动更新父布局");
		layouts = root.layouts;
		child.centerX = 10;
		child.centerY = 20;
		child.left = child.right = child.top = child.bottom = null;
		child.localToGlobal(new Point());
		check(root.layouts == layouts, "直接锚点属性的相同赋值不重复布局");
		var horizontal:HorizontalLayout = new HorizontalLayout();
		horizontal.verticalAlign = TOP;
		root.layout = horizontal;
		point = child.localToGlobal(new Point());
		check(point.x == 0 && !root.__layoutDirty, "运行时替换布局策略立即参与下次查询");
		root.layout = null;
		check(root.__layoutDirty, "移除布局策略也标记布局失效");
		child.localToGlobal(new Point());
		check(!root.__layoutDirty, "移除布局策略后的失效可正常消费");
		child.layoutData = null;
		check(root.__layoutDirty, "移除布局数据也标记父容器布局失效");

		var container:BoxContainer = new BoxContainer();
		var inside:LayoutProbe = new LayoutProbe();
		container.width = 120;
		container.height = 80;
		container.layout = new AnchorLayout();
		inside.layoutData = AnchorLayoutData.fill();
		container.addChild(inside);
		container.__updateLayout();
		inside.layoutData = new AnchorLayoutData(10, 20, 10, 20);
		point = inside.localToGlobal(new Point());
		check(point.x == 20 && point.y == 10 && inside.width == 80 && inside.height == 60,
			"BoxContainer 的锚点变更通知实际承载子对象的内部容器");
		var insideData:AnchorLayoutData = cast inside.layoutData;
		insideData.left = 30;
		container.invalidateLayout();
		point = inside.localToGlobal(new Point());
		check(point.x == 30 && inside.width == 70 && !container.box.__layoutDirty,
			"BoxContainer 显式失效同步通知内部容器");
	}

	/** 布局成员变化时重新排列，普通可见性开关仍保留原布局占位。 */
	private static function checkLayoutParticipation():Void {
		var root:LayoutProbe = new LayoutProbe();
		var first:Quad = new Quad(40, 20);
		var second:Quad = new Quad(30, 20);
		root.width = 200;
		root.height = 80;
		var horizontal:HorizontalLayout = new HorizontalLayout();
		horizontal.verticalAlign = TOP;
		root.layout = horizontal;
		root.addChild(first);
		root.addChild(second);
		root.__updateLayout();
		check(second.x == 40, "水平布局初始排列正确");
		first.hide = true;
		check(second.localToGlobal(new Point()).x == 0, "hide 改变后重新排列后续对象");
		first.hide = false;
		check(second.localToGlobal(new Point()).x == 40, "恢复 hide 后重新加入布局");
		first.includeInLayout = false;
		check(second.localToGlobal(new Point()).x == 0, "退出布局后更新后续对象位置");
		first.includeInLayout = true;
		check(second.localToGlobal(new Point()).x == 40, "重新参与布局后恢复排列");
		var layouts:Int = root.layouts;
		first.hide = false;
		first.includeInLayout = true;
		second.localToGlobal(new Point());
		check(root.layouts == layouts, "布局成员状态的相同赋值不重复布局");
		first.visible = false;
		check(second.localToGlobal(new Point()).x == 40, "visible 不改变布局成员与占位");
	}

	/** 子类在 super.updateLayout 后修改锚点，新失效必须留给下一次查询。 */
	private static function checkLayoutDataDuringUpdate():Void {
		var root:ChangingLayoutProbe = new ChangingLayoutProbe();
		var child:LayoutProbe = new LayoutProbe();
		root.width = 200;
		root.height = 100;
		root.layout = new AnchorLayout();
		child.width = 20;
		child.height = 20;
		child.layoutData = AnchorLayoutData.topLeft();
		root.target = child;
		root.addChild(child);
		root.__updateLayout();
		check(root.__layoutDirty && child.x == 0, "布局结束后修改锚点保留新的失效");
		check(child.localToGlobal(new Point()).x == 30 && !root.__layoutDirty,
			"后续坐标查询消费布局期间产生的锚点变更");
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

/** 模拟组件在父类布局完成后更新自己的子对象锚点。 */
private class ChangingLayoutProbe extends Box {
	public var target:DisplayObject;
	private var changed:Bool = false;

	override public function updateLayout():Void {
		super.updateLayout();
		if (!changed) {
			changed = true;
			target.layoutData = AnchorLayoutData.topLeft(0, 30);
		}
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
