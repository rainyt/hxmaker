# Hxmaker 桌面工具：供 AI 使用的建项与开发规范

本文用于让 AI 从空目录创建基于 Hxmaker 的桌面工具或编辑器。可以直接复制到新项目，并在任务开始时让 AI 先阅读。文中的通用约定适用于资源工具、配置工具、地图编辑器等；多文档、自由画布、工程索引等按实际需求添加。

## 1. 可直接交给 AI 的任务提示词

```text
请先阅读项目中的 AGENTS.md、README.md 和本文，再开始工作。

目标：使用 Haxe + Hxmaker + OpenFL + Electron 创建桌面工具。
工具名称：<填写名称>
主要用途：<填写用途>
首批功能：<列出本次必须完成的功能>
工作目录：<填写目录>

入口 Main 必须继承 hx.core.HxmakerApplication；通过自定义 Hxmaker Stage
启动界面。使用 Hxmaker 原生渲染，静态界面使用 XML，不使用 IFrame。
窗口大小、被编辑内容的逻辑尺寸和画布镜头必须独立。
默认不自动打开文件，也不自动创建文档。

所有交流、文档和代码注释使用简体中文，代码标识符使用英文。
默认由我进行功能测试。你可以做编译和静态检查，不要自行运行功能测试。
只提交本次任务的改动到本地 Git，不混入已有修改，不自动 push。
完成后启动最新可用的工具，并说明提交记录和本次实际执行的检查。
```

后续任务中的明确要求优先于本文默认约定。本文不是要求把现有 GUI 编辑器的全部功能复制到每一个新工具。

## 2. 必须遵守的基础约定

| 项目 | 约定 |
| --- | --- |
| 交流、文档、注释 | 简体中文 |
| 类名、变量名、函数名 | 英文 |
| 启动基类 | `hx.core.HxmakerApplication`，以源码中的实际拼写为准 |
| 渲染 | Hxmaker 原生显示对象，不使用 IFrame 承载工具界面或编辑预览 |
| 界面组织 | XML 描述静态结构，Haxe 管理交互、动态控件和业务状态 |
| 初始状态 | 没有打开的文档；可以有欢迎页、打开入口或空状态提示 |
| 关闭最后一份文档 | 保持空状态，不自动补建文件 |
| 测试 | 默认由用户进行；AI 做编译和静态检查，用户明确授权后才执行对应范围的功能测试 |
| Git | 自主提交本次任务到本地；保留已有修改，不自动 push |
| 交付 | 启动最新可用版本；不要擅自关闭可能有未保存内容的旧窗口 |

启动继承链应当清楚地区分应用、舞台和界面：

```text
Main extends hx.core.HxmakerApplication
  └─ init(ToolStage, 0, 0)
       └─ ToolStage extends hx.display.Stage
            └─ AppMain extends hx.display.UILoadScene
                 └─ XML 布局及业务面板
```

## 3. 开始前先检查现有环境

1. 阅读本项目已有说明和约定，查看 `git status --short --branch`。
2. 检查 `haxe --version`、`neko -version`、`haxelib list`、`node --version`。
3. 使用 `haxelib libpath hxmaker`、`haxelib libpath hxmaker-openfl`、`haxelib libpath lime` 定位实际源码。
4. 阅读当前版本的 `hx.display`、`hx.layout`、`hx.ui.UIManager` 和 `hx.ui.UIAssets`，确认需要使用的 API 确实存在。
5. 优先复用当前机器已验证的构建环境和依赖锁文件；需要调整依赖时说明原因。

本参考项目使用 Haxe、Neko、Lime、OpenFL、`hxmaker`、`hxmaker-openfl`、`actuate`、`electron` 和 `hxnodejs` 等依赖。实际传递依赖还取决于本机 Hxmaker 后端配置，不能只依据 `haxelib.json` 是否列出了依赖来判断环境完整。

不要猜测控件 API。例如本项目的 `EditorButton`、`EditorTextInput`、`EditorCheckBox`、`SourceInput`、`PanelBox` 是工具自身封装，并非都存在对应的 Hxmaker 内置类。

## 4. 空项目建议目录

```text
新工具/
  AGENTS.md
  README.md
  project.xml
  package.json
  package-lock.json
  Makefile
  .gitignore
  Source/
    Main.hx
    ToolStage.hx
    model/                   文档、工程、历史、资源映射等业务模型
    ui/
      AppMain.hx
      PanelBox.hx            需要独立 XML 面板时再添加
      components/            可复用控件
  assets/
    ui/
      app_main.xml
    images/
    config/
  templates/
    electron/
      haxe/ElectronSetup.hx
      hxml/debug.hxml
      hxml/release.hxml
      template/
        package.json
        main.cjs
  docs/
    HXMAKER_AI_TOOL_GUIDE.md
```

以上新项目示例统一使用小写 `assets/`，使宏读取路径、物理目录和运行时资源地址在大小写敏感的文件系统上也一致。已有项目如使用 `Assets/`，保留现有命名并核对路径映射，不要为了套模板重命名全部资源。

`Export/`、`node_modules/` 和打包产物不提交 Git。参考 `.gitignore`：

```gitignore
Export/
dist/
node_modules/
.DS_Store
*.log
```

## 5. 最小启动代码

### `Source/Main.hx`

```haxe
import hx.core.HxmakerApplication;

/** 应用入口：渲染尺寸跟随窗口，业务从自定义舞台启动。 */
class Main extends HxmakerApplication {
    public function new() {
        super();
        hx.display.TextFormat.defaultFont = "sans-serif";
        init(ToolStage, 0, 0);
    }
}
```

### `Source/ToolStage.hx`

```haxe
import hx.display.Stage;
import ui.AppMain;

class ToolStage extends Stage {
    override function onStageInit() {
        super.onStageInit();
        addChild(new AppMain());
    }
}
```

### `Source/ui/AppMain.hx`

```haxe
package ui;

import hx.display.UILoadScene;
import hx.display.Splitter;
import hx.display.SplitterBox;

@:build(hx.macro.UIBuilder.build("assets/ui/app_main.xml"))
class AppMain extends UILoadScene {
    // 保留仅由 XML 引用的类型，避免编译裁剪后运行时无法创建组件。
    private static var components:Array<Class<Dynamic>> = [SplitterBox, Splitter];

    override function onLoaded():Void {
        super.onLoaded();
        statusLabel.data = "就绪 · 请新建或打开文件";
    }
}
```

### `assets/ui/app_main.xml`

```xml
<Box width="100%" height="100%">
    <Quad width="100%" height="100%" color="0x171b22" mouseEnabled="false"/>
    <Box width="100%" height="48">
        <Quad width="100%" height="100%" color="0x202630"/>
        <Label left="16" top="12" width="260" height="26"
               text="新工具" fontSize="18" color="0xe8edf4"/>
    </Box>
    <SplitterBox top="49" bottom="29" width="100%">
        <Box size="220">
            <Quad width="100%" height="100%" color="0x202630"/>
            <Label left="14" top="14" width="180" height="24"
                   text="资源" fontSize="14" color="0xe8edf4"/>
        </Box>
        <Splitter direction="vertical" color="0x11151c"/>
        <Box>
            <Label left="20" right="20" top="24" height="28"
                   text="尚未打开文件" fontSize="14" color="0x8898ab"/>
        </Box>
        <Splitter direction="vertical" color="0x11151c"/>
        <Box size="300">
            <Quad width="100%" height="100%" color="0x202630"/>
            <Label left="14" top="14" width="260" height="24"
                   text="属性" fontSize="14" color="0xe8edf4"/>
        </Box>
    </SplitterBox>
    <Quad bottom="0" width="100%" height="28" color="0x202630"/>
    <Label id="statusLabel" left="14" right="14" bottom="5" height="18"
           fontSize="11" color="0x99a8bc"/>
</Box>
```

这只是界面外壳，不应在启动时创建假文档来填充空状态。工具不需要三栏时，按业务调整布局。

## 6. 工程与 Electron 配置

### `project.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<project>
    <meta title="新工具" package="com.rainyt.newtool" version="0.1.0" company="RainyT"/>
    <app main="Main" path="Export" file="NewTool"/>
    <!-- 渲染面随客户区变化，初始窗口尺寸由 Electron 主进程设置。 -->
    <window width="0" height="0" resizable="true" background="0x171b22"/>
    <source path="Source"/>
    <haxelib name="hxmaker-openfl"/>
    <haxelib name="actuate"/>
    <haxelib name="electron" if="electron"/>
    <assets path="assets" rename="assets" embed="false"/>
    <template path="templates"/>
</project>
```

### `templates/electron/haxe/ElectronSetup.hx`

```haxe
class ElectronSetup {
    static function main() {
        js.Syntax.code("require('./main.cjs')");
    }
}
```

### `templates/electron/template/package.json`

```json
{
  "name": "new-tool",
  "version": "::meta.version::",
  "main": "ElectronSetup.js"
}
```

### `templates/electron/template/main.cjs`

```javascript
const { app, BrowserWindow } = require('electron');
const path = require('node:path');

process.chdir(__dirname);
let window;

app.whenReady().then(() => {
  window = new BrowserWindow({
    width: 1440, height: 900, minWidth: 1200, minHeight: 700,
    title: '新工具', backgroundColor: '#171b22',
    webPreferences: { nodeIntegration: true, contextIsolation: false },
  });
  window.setMenuBarVisibility(false);
  window.webContents.on('will-navigate', event => event.preventDefault());
  window.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  window.loadFile(path.join(__dirname, 'index.html'));
});

app.on('window-all-closed', () => app.quit());
```

上述模板沿用本参考项目的本地可信渲染进程模式。界面由 Lime/OpenFL 输出的页面启动 Hxmaker；文件对话框、写盘、窗口关闭确认等通过主进程 IPC 扩展。不要在主进程堆放编辑业务，也不要把此模式直接用于加载远程网页。

### `templates/electron/hxml/debug.hxml`

```hxml
--each

--next
-js ::OUTPUT_FILE::
-cp ::OUTPUT_DIR::/haxe
-main ApplicationMain ::HAXE_FLAGS::
-D electron
-D html5
-D html
-debug

--next
-js ::OUTPUT_DIR::/bin/ElectronSetup.js
-cp ::OUTPUT_DIR::/haxe
-main ElectronSetup
-lib hxnodejs
-dce full
-D electron
-D html5
-D html
-debug
```

`release.hxml` 使用相同的双目标结构，移除两个 `-debug`。一部分模板版本只覆盖渲染端，不能遗漏 `ElectronSetup` 主进程目标。Lime 模板占位符交给 Lime 展开，不手工替换成某次构建的绝对路径。

根目录 `package.json` 中提供 `build` 和 `start` 脚本，Electron 使用项目级依赖并提交 `package-lock.json`。本参考仓库曾使用锁定版本 `44.7.2`；这是本机工程配置记录，不是未来项目必须使用的版本。优先沿用已验证环境中的锁定版本。

## 7. 编译和启动约定

新工具至少提供以下命令接口：

```makefile
LIME ?= haxelib run lime
ELECTRON ?= node_modules/.bin/electron

.PHONY: install build run
install:
	npm ci --no-audit --no-fund
build:
	$(LIME) build electron -debug
run: build
	$(ELECTRON) Export/electron/bin
```

Makefile 命令行前使用实际 Tab。首次建立锁文件时才使用对应的依赖安装命令生成 `package-lock.json`，已有锁文件后使用 `npm ci`。

常用操作：

```sh
make build                         # 仅编译
make run                           # 编译并启动
node_modules/.bin/electron Export/electron/bin  # 启动已有编译产物
node --check templates/electron/template/main.cjs  # 主进程语法检查
git diff --check                   # 检查补丁格式
```

环境兼容经验：

- Haxe 标准库未自动找到时，定位当前 Haxe 安装并配置 `HAXE_STD_PATH`，不要把某台机器的 SDK 路径作为跨机器要求。
- 本机 Apple Silicon 曾使用 Intel Neko 和旧版 Lime 原生库，需要通过 Rosetta 执行 Lime；这是具体环境兼容，不是所有项目都必须强制使用 x86_64。
- 需要复用该兼容逻辑时参考本参考仓库的 `Makefile`。如果命令先切换到了 Lime 目录，要显式把工具工程目录传给 Lime，避免构建错误目录。
- 不手工修改 `Export/` 中的生成文件来修复源工程，应修改 `Source/`、`assets/` 或 `templates/` 后重新构建。

本任务默认不执行 `make check`、`make check-ui`、`npm test` 或鼠标键盘自动化。编译成功与功能测试通过必须分开报告；启动应用供用户使用不等于已经测试功能。

## 8. XML、组件和生命周期

### XML 负责结构，Haxe 负责行为

- `UIBuilder.build(...)` 在编译时解析 XML，生成 `ids`、`getChildById()` 和带 `id` 的字段；控件要在加载完成后访问。
- 主界面继承 `UILoadScene`，在 `onLoaded()` 中绑定事件，并调用 `super.onLoaded()`。
- XML 中引用自定义组件时使用完整类名，例如 `<ui.components.EditorButton .../>`。
- 对仅在 XML 中使用的类提供明确的类型引用和必要的 `@:keep`，防止 DCE 后无法通过运行时类名创建。
- `components` 这样的数组用于保留类型，它的名称不是魔法注册 API；需要额外属性解析时仍须调用 `UIManager.addAttributesParse(...)`。

### 独立面板

复杂工具可借鉴本参考项目的 `PanelBox`：继承 `Box`，通过 `@:build(UIBuilder.build(...))` 绑定独立 XML，在加入舞台后加载 `UIAssets`，构建完成再调用 `onPanelBuild()`。

注意：

- `PanelBox` 是本项目封装，复制使用时必须一并提供源码。
- 通过 `UIManager.bindAssets()` 绑定资源后，在销毁时配对 `unbindAssets()` 和 `clean()`。
- 由外部 `SplitterBox` 分配尺寸的面板 XML 根节点不要再声明 `width`、`height`，避免覆盖宿主尺寸规则。
- 监听舞台、共享上下文或浏览器的事件时，销毁组件要配对移除。
- Hxmaker 的 `dispose()` 不应当被当作自动移出父级使用，通常先 `remove()` 再 `dispose()`。

### 控件选择

| 需求 | 优先方式 |
| --- | --- |
| 普通布局 | `Box`、锚点、`VBox`、`HBox`、`SplitterBox` |
| 单列大量条目 | 原生 `ListView` 与虚拟布局 |
| 分目录选择资源 | `FinderView` 加搜索和预览 |
| 有展开层级的数据 | 确实有需要时使用 `Tree` |
| 编辑属性 | 文本 / 数值输入、布尔复选框、资源选择器分别处理 |
| 右键菜单 | 检查本机 `ContextMenu` API，优先复用原生菜单能力 |

基础 `Button` 的显示依赖皮肤等配置。可复用本项目的 `EditorButton`、`EditorTextInput` 等深色控件，或者在新工具中提供等价封装，不要假设默认按钮会自动获得完整工具皮肤。

属性解析默认未必沿自定义类的继承关系回溯。为自定义按钮注册文本、颜色等 XML 解析器时，核对本机 `UIManager.applyAttributes()` 的行为；只写了 XML 属性但没有对应解析器，运行时可能没有效果。

## 9. 编辑器类工具的数据约定

以下内容适用于确实需要编辑文档的工具，可按业务裁剪：

- 文档模型与显示对象分离。保存的是用户文档，不保存预览对象、辅助框或镜头变换。
- 打开操作先成功读取并验证新内容，再切换界面；用户取消或读取失败时保留原状态。
- 多 Tab 各自保留文档、保存点、撤销历史、选中项和镜头；相同文件应切换已有 Tab。
- 保存异步回调绑定发起保存的那份文档，不能在回调中临时取“当前 Tab”作为保存目标。
- 保存期间的新修改仍然是未保存状态。关闭窗口、切换工程时检查全部文档的未保存修改。
- 一个拖拽动作形成一条历史记录；取消拖拽恢复临时显示，不产生记录。
- 悬浮资源选择器先维护草稿，点击“应用”才写入属性；“取消”不写回。
- 编辑器临时隐藏、锁定、选框、错误占位等辅助状态，不擅自写入用户 XML。
- 资源地址优先保留工程 `assets path/rename` 映射，避免写入本机特有的绝对路径。
- 工程配置可能含证书、密钥或其他敏感字段，读取时只输出任务需要的结构，不把全文打印到日志。

本 GUI 编辑器约定通过 `project.xml` 读取工程配置，这属于该工具的产品行为；其他工具应根据自己的文件格式设计打开入口。

## 10. 有画布时的尺寸与输入约定

必须区分三套概念：

1. **窗口 / 客户区尺寸**：控制桌面工具外壳与渲染面。
2. **文档逻辑尺寸**：例如 1080×1920 的设计稿。
3. **镜头**：只负责文档的平移和缩放。

不要为了显示大画布固定窗口分辨率，也不要用编辑器窗口宽高代替文档逻辑尺寸。将设计内容放进独立容器，镜头操作只改变该容器。

本项目已处理过的边界，可作为后续画布工具的实现参考：

- `Scene`、全屏填充图片和嵌套 `xml:...` 预览要共享文档逻辑尺寸；普通工具外壳仍读取窗口尺寸。
- 布局控制的子对象不能单靠修改显示坐标完成移动，要同步锚点或对应布局数据。
- 一次拖动只使用一套坐标来源，处理缩放、高清屏和父级旋转；避免混用原生事件坐标与引擎上一帧坐标。
- 镜头更新后同步变换，再计算选框与手柄；不能继续读取上一帧世界矩阵。
- 被裁剪容器的滚动范围与点击热区要覆盖行间空隙。大量内容优先使用原生 `Scroll` / 虚拟列表，而不是各自实现不一致的滚轮逻辑。
- 浮窗打开时阻止画布原生输入监听和文件快捷键穿透，保留输入框自己的文本编辑行为。
- 异步预览使用版本号或取消标记；关闭文件、切换 Tab 后，旧加载回调不能重新显示旧页面。
- 对象被删除、撤销后会重新解析 XML，仅用路径存放辅助状态可能把隐藏或锁定状态移到其他节点，应保留节点身份关系。

这些是实现要点，不要求每个空工具都预先加入自由画布和整套文档编辑器。

## 11. 推荐开发顺序与交付标准

1. 建立依赖、启动链、Electron 模板和可伸缩窗口，先让外壳能够编译运行。
2. 提供默认空状态和最小界面分区，按需求添加工具栏与状态提示。
3. 建立数据模型，再接入文件操作、具体控件和编辑行为。
4. 处理无文档、取消、读取失败、未保存修改、窗口缩放和异步回调的边界。
5. 进行用户允许的编译与静态检查，清楚说明未执行的功能测试。
6. 更新中文 README，明确启动命令、当前功能与实际限制。
7. 只暂存本次文件，检查暂存补丁并提交本地 Git。工作区有其他修改时保留它们。
8. 功能任务完成后启动本次构建供用户测试；纯文档任务不必为了文档重编译现有功能代码。

交付时简要说明：做了什么、如何打开或使用、实际执行了哪些检查、提交号及启动状态。不要把“编译成功”写成“所有功能测试通过”。

## 12. 本参考仓库中的可复用实现

以下为相对于 `hxmaker-gui-editor` 仓库根目录的路径，可按需要阅读或复制。实际文件可能包含该编辑器专用逻辑，迁移时去除不需要的依赖。

| 文件 / 目录 | 参考内容 |
| --- | --- |
| `Source/Main.hx`、`Source/EditorStage.hx` | 应用与舞台启动 |
| `Source/ui/AppMain.hx`、`Assets/ui/app_main.xml` | XML 主界面与布局分区 |
| `Source/ui/PanelBox.hx` | 独立 XML 面板的异步构建 |
| `Source/ui/components/` | 按钮、输入框、复选框、列表与资源属性输入 |
| `Source/ui/SourcePicker.hx` | Finder 搜索、资源地址输入与图片预览 |
| `Source/editor/EditorDocument.hx`、`DocumentSession.hx` | 文档事务、历史与多文件会话 |
| `Source/editor/ProjectModel.hx` | 配置资源路径映射 |
| `Source/editor/PreviewSize.hx`、`PreviewScene.hx` | 逻辑分辨率与嵌套预览 |
| `Source/ui/PointerCoordinates.hx`、`Source/editor/DragProjection.hx` | 鼠标坐标与手势投影 |
| `Source/editor/ModifierKeySync.hx` | 原生修饰键同步和失焦清理 |
| `templates/electron/` | Electron 入口、双目标 HXML 和主进程 IPC |
| `Makefile`、`project.xml` | 编译启动与本机环境兼容 |

在新项目的 `AGENTS.md` 中可以写：

```markdown
## Hxmaker 工具开发

- 开发前先阅读 docs/HXMAKER_AI_TOOL_GUIDE.md。
- 所有交流、文档和代码注释使用简体中文；代码标识符使用英文。
- Main 继承 hx.core.HxmakerApplication，使用 Hxmaker 原生渲染和 XML 界面。
- 默认不打开文档，关闭最后一页后保持空状态。
- 默认由用户进行功能测试；AI 可编译和静态检查，不自行运行功能测试。
- 自主提交本次任务的本地 Git 记录，不混入已有修改，不自动 push。
- 完成功能后启动最新版本供用户测试，不关闭有潜在未保存内容的旧窗口。
```
