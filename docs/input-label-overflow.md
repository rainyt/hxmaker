# 输入框溢出处理

`InputLabel` 使用固定视口和可滚动内容容器。文本、选区或光标超出视口时才启用内部 `maskRect`；内容重新放入范围后自动关闭遮罩。背景不参与内容滚动。

```haxe
var input = new InputLabel();
input.width = 200;
input.height = 32;
input.wordWrap = false; // 单行输入，长文本随光标横向滚动
input.data = "可以持续输入的文本";
stage.addChild(input);
```

`wordWrap` 保持原来的默认值 `true`。多行文本随光标纵向滚动，跨行选区按行绘制。拖拽到边缘外时会继续滚动；鼠标按下即接入原生输入通道，在文字或输入框外抬起时仍可删除、替换选区。

设置 `wordWrap = false` 后，输入组件阻止 Enter 和 Shift+Enter 插入换行，直接赋值、粘贴和微信键盘回调中的 `\r`、`\n` 也会被移除。例如 `ab\r\ncd` 变为 `abcd`，光标和选区按照移除字符的位置同步修正。切换到单行时会清理已有换行。中文输入法的候选确认键保持可用，组合输入结束后才提交和过滤文本。普通 `Label.wordWrap` 的语义不变。

空文本的光标按自身宽高对齐：垂直居中位置为 `(height - line.height) / 2`，底部对齐位置为 `height - line.height`。文字测量高度为零时，光标不会把文字原点误当作自身顶部；只要光标能放入视口，就不会因此产生滚动或启用遮罩。有提示文案、删除最后一个字符及改变字号时采用相同规则。

提示文案也会裁剪；空格属于已输入内容，不显示提示文案。密码模式按原文索引处理选区，并按显示后的掩码文本测量。

裁剪矩形和选区色块会复用。静止文本仅比较缓存状态，不重新排字或扫描字符；变换、滚动和光标闪烁不触发文本布局重建。

OpenFL 后端同步提供 `ITextFieldLayoutProvider` 可选接口，返回包含尾部空白和末尾空行的布局边界、插入位置及布局版本。原有 `ITextFieldDataProvider` 接口保持兼容。后端遮罩改用栈管理，输入框可嵌套在已有遮罩的滚动容器中，遮罩容器通过对象池复用。

## 验证

```bash
haxe test/input-label-overflow.hxml
node -r ./test/context-menu-preload.js bin/input-label-overflow-check.js
haxe test/input-label-single-line.hxml
node -r ./test/context-menu-preload.js bin/input-label-single-line-check.js
haxe test/input-label-single-line-wechat.hxml
node -r ./test/context-menu-preload.js bin/input-label-single-line-wechat-check.js
```

行为检查使用固定字形尺寸，执行真实文本布局、显示树、命中与输入选区逻辑，不初始化 GPU。已有的 DOM 预加载脚本用于 OpenFL 静态初始化。

浏览器检查额外启用 `overflow_browser_checks`，需要页面提供 `result` 和 `native-result` 元素。它使用可读 Canvas 位图验证普通绘制及位图缓存模式的嵌套裁剪，并保留一次“输入框外抬起后的选区”供实际按 Backspace 验证。GPU 位图路径需要完整 OpenFL 舞台，未在此独立检查中运行。
