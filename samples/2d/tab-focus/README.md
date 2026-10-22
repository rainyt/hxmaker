# Tab 焦点切换示例

在本目录运行：

```bash
haxelib run openfl test project.xml html5
```

依赖已注册到本地 haxelib 的当前版本 `hxmaker`、`hxmaker-openfl`，以及 `spine-haxe`、`actuate`。入口 `Main` 继承 `HxmakerApplication`，通过 `init(GameStage, 800, 600)` 初始化业务舞台。

示例包含用户名、邮箱、密码三个输入框、一个不参与 Tab 的备注输入框，以及独立实现 `ITabFocusable` 的 `FocusableTile`。当前焦点以蓝色背景和顶部文字显示。

可观察的交互行为：

1. 初始没有焦点，直接按 Tab，不会自动选中输入框。
2. 点击用户名后，Tab 按“用户名 → 邮箱 → 密码 → 自定义组件”循环；Shift+Tab 反向切换。切入输入框后可以直接打字。
3. 点击“清空焦点”，再次按 Tab 不会开始查询。
4. 备注设置了 `tabEnabled = false`，可点击编辑，但既不作为 Tab 候选对象，也不能作为切换起点。
5. 点击“切换邮箱是否参与”，重新点击用户名后，观察邮箱是否被跳过。
6. 点击自定义组件后按 Tab，同样可以进入输入框；它通过接口接入，无需额外注册。

示例不在启动时主动获取焦点。控制按钮属于普通显示对象，不参与 Tab 序列。

接口与排序规则见[Tab 焦点切换说明](../../../docs/Tab焦点切换.md)。本示例尚未运行编译或交互测试。
