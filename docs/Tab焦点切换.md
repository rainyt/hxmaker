# Tab 焦点切换

显示对象实现 `hx.display.ITabFocusable` 后可以参与舞台内的 Tab 焦点切换。`InputLabel` 已实现该接口，默认启用。

可运行示例见 [samples/2d/tab-focus](../samples/2d/tab-focus/README.md)，包含输入框、自定义接口组件、清空焦点和动态排除候选对象。

必须先选中一个支持切换的焦点对象。没有焦点、焦点未实现接口、`tabEnabled = false` 或 `tabIndex < 0` 时，不查询显示树，也不会通过 Tab 自动选中第一个输入框。

## 输入框

```haxe
var nameInput = new InputLabel();
nameInput.width = 200;
nameInput.height = 32;
nameInput.wordWrap = false;
nameInput.tabIndex = 0;
addChild(nameInput);

var passwordInput = new InputLabel();
passwordInput.width = 200;
passwordInput.height = 32;
passwordInput.y = 40;
passwordInput.wordWrap = false;
passwordInput.displayAsPassword = true;
passwordInput.tabIndex = 1;
addChild(passwordInput);

// 用户点击输入框，或业务主动调用 focus()，才能开始通过 Tab 切换。
nameInput.focus();
```

Tab 向后切换，Shift+Tab 向前切换，首尾循环。候选对象先按 `tabIndex` 从小到大排序，同值按显示树的深度优先顺序排列；默认 `tabIndex = 0`，无需为每个输入框指定序号。

隐藏、完全透明、`mouseEnabled = false`、已移除或已销毁的对象不会参与；父节点处于这些状态时，其子树也不会参与。`mouseChildren = false` 的容器仍可自行参与，但不遍历内部子对象。仅有当前对象时保留焦点，接管 Tab，避免浏览器移走原生焦点。

输入框失焦时立即收起选区、隐藏光标并关闭自己的原生输入通道。新输入框被选中后立即调用 `focus()`，接管后续文字输入。

## 自定义组件

```haxe
import hx.display.ITabFocusable;
import hx.display.Quad;

class FocusableQuad extends Quad implements ITabFocusable {
	public var tabEnabled:Bool = true;
	public var tabIndex:Int = 0;

	public function new() {
		super(120, 32, 0x336699);
	}

	public function focus():Void {
		// 支持业务直接调用；通过 Tab 切换时，舞台已提前设置 stage.focus。
		if (stage != null)
			stage.focus = this;
		// 按需接入输入通道；焦点样式也可通过 FOCUS_OVER、FOCUS_OUT 事件维护。
	}
}
```

接口中的 `focus()` 是切换完成后的激活入口。舞台负责设置 `stage.focus`，自定义组件在方法中接入输入通道或维护交互状态，不需要单独注册到焦点管理器。通过鼠标选中对象时沿用已有的舞台焦点逻辑。

业务也可调用 `stage.focusNext()` 或 `stage.focusNext(true)`，它们使用相同的起点约束，返回是否接管本次切换。

## 键盘事件与平台

舞台先分发按键，再执行默认切换。当前组件或其父节点可以在 Tab 的 `KEY_DOWN` 监听中调用 `event.preventDefault()` 接管行为；监听期间已经改变焦点时，舞台不会再额外切换。Ctrl、Alt、Command 组合键和输入法组合阶段不执行默认切换。

HTML5 使用浏览器捕获阶段的单一监听，将当前接口焦点的 Tab 交给所属舞台，阻止同一次按键再次经过后端。引擎接管切换后才阻止浏览器默认行为，避免隐藏输入框丢失原生焦点。页面其他原生编辑控件获得焦点时保留其自身的 Tab 行为。

其他平台由后端通过 `Stage.handleKeyboardEvent()` 传入实体键盘事件。微信软键盘没有提供 Tab 导航事件，需要业务按钮主动调用 `focusNext()`。

本次实现尚未运行编译、自动化或浏览器交互测试。
