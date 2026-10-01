# FinderView — 资源选择器（访达风格列表）

本文档介绍 `FinderView`（资源选择器）组件，以及配套的 `FinderItemRenderer`（默认行渲染器）。

`FinderView` 继承自 `Scroll`，是一个类似 Mac 访达（Finder）的**逐级浏览**列表：它与 `Tree` 共用 `TreeItem` 数据模型，但不做树形展开——一次只显示当前目录的一层子项，单击选中、**双击文件夹进入下一级**，适合资源浏览器、打开文件对话框等场景。数据源不绑定文件系统，由使用方预先构建 `TreeItem` 树。

## 基本用法

```haxe
import hx.display.FinderView;
import hx.display.TreeItem;
import hx.events.Event;

var finder = new FinderView();
finder.width = 260;
finder.height = 400;
finder.x = 50;
finder.y = 50;

// 与 Tree 相同的 TreeItem 数据模型，children 有内容的节点是文件夹
var assets = new TreeItem("assets", [
    new TreeItem("audio", [new TreeItem("bgm.ogg"), new TreeItem("shoot.wav")]),
    new TreeItem("images", [new TreeItem("hero.png")]),
]);
var data = [
    new TreeItem("src", [new TreeItem("Main.hx"), new TreeItem("Player.hx")]),
    assets,
    new TreeItem("project.hxml"),
];
finder.data = data;

// 监听选择变化
finder.addEventListener(Event.CHANGE, function(event) {
    trace("选中了：" + finder.selectedItem.label);
});

this.addChild(finder);
```

## 目录导航

### 双击进入

双击文件夹时组件自动进入下一级：

```haxe
// 双击任何行都会派发，event.data 为被双击的节点
finder.addEventListener(FinderView.ITEM_DOUBLE_CLICKED, function(event) {
    var item:TreeItem = event.data;
    if (!item.isFolder) {
        openFile(item);            // 双击文件：用作"打开/确认"的钩子
    }
});

// 目录变化（进入/返回/跳转）都会派发，event.data 为新目录（根层级为 null）
finder.addEventListener(FinderView.PATH_CHANGED, function(event) {
    trace("当前目录：" + finder.currentItem != null ? finder.currentItem.label : "根");
});
```

事件的派发顺序：双击文件夹时先派发 `ITEM_DOUBLE_CLICKED`，进入后派发 `PATH_CHANGED`。目录切换后选择自动清空，列表回到顶部。

### `..` 返回上级行

`showParentRow` 默认开启，非根层级时列表第一行显示 `..`，双击它返回上一级（等价于 `goUp()`，会自动选中刚退出的文件夹）：

```haxe
finder.showParentRow = false;      // 关闭 .. 行
```

`..` 行是组件内部的哨兵节点（只读属性 `parentItem`），不是数据源中的节点：它计入 `rowCount`、可以被选中，但目录切换后选中会自动清除；双击它是纯导航行为，不派发 `ITEM_DOUBLE_CLICKED`。需要区分选中项时用 `finder.selectedItem == finder.parentItem` 判断。

### 导航 API

```haxe
finder.goInto(item);               // 进入指定文件夹（非文件夹时返回 false）
finder.goUp();                     // 返回上一级，并自动选中刚退出的文件夹（访达行为）
finder.goToRoot();                 // 回到根层级
finder.currentItem = assets;       // 直接跳转（与 goInto 等价，null 表示根层级）
finder.currentItem;                // 当前目录节点，null 表示根层级
finder.path;                       // 从根到当前目录的节点链，如 [assets, audio]
```

`path` 可用于自建面包屑导航：目录变化时根据 `path` 重建路径栏，点击路径中的任意一级就把 `currentItem` 设置为该节点。

## 选择

与 `Tree` 一致的多选行为，选择变化时派发 `Event.CHANGE`：

| 操作 | 行为 |
|------|------|
| 点击 | 只选中该行 |
| `Ctrl`/`Cmd` + 点击 | 切换该节点的选中状态（追加/移除多选） |
| `Shift` + 点击 | 选中锚点到当前行的区间（替换整个选择） |
| `Ctrl`/`Cmd` + `Shift` + 点击 | 把区间追加到当前选择 |
| 右键点击 | 只把未选中的节点改为单选，已选中的保留多选（配合右键菜单） |

- 单击只改变选择，**不会**进入文件夹（导航只由双击触发，与访达一致）
- 选择只在当前目录内有效，切换目录后自动清空
- `selectedItem` 是主选中项（最后交互的节点），`selectedItems` 是全部选中项（保持选择顺序）
- 程序化选择：`selectedItem = node`（节点必须在当前目录内）、`selectedIndex = 2`、`clearSelection()`

```haxe
finder.foldersFirst = true;        // 文件夹稳定排在文件前面（不修改数据源顺序）
finder.rightClickSelectEnabled = false;   // 关闭右键选择
```

## 自定义行渲染器

默认渲染器 `FinderItemRenderer` 提供选中/悬停背景、类型图标（文件夹/文件）与文本展示。需要贴图图标或更复杂的展示时继承它：

```haxe
import hx.display.FinderItemRenderer;
import hx.display.TreeRowData;
import hx.display.Image;

class ResourceItemRenderer extends FinderItemRenderer {
    var icon:Image;

    override function onInit():Void {
        super.onInit();
        icon = new Image();
        this.addChild(icon);
    }

    override function setData(value:Dynamic):Void {
        super.setData(value);
        var row:TreeRowData = value;   // item 为节点，depth 恒为 0
        icon.data = UIManager.getBitmapData(row.item.isFolder ? "icon_folder" : "icon_file");
        icon.x = FinderItemRenderer.PADDING_LEFT;
        // 文本位置由父类维护，把文本右移让出图标位置即可
        this.label.x = icon.x + icon.width + 4;
    }
}

finder.itemRendererRecycler = new DisplayObjectRecycler(ResourceItemRenderer);
```

渲染器的 `data` 是 `TreeRowData` 结构（与 `Tree` 相同，`depth` 恒为 `0`），因此自定义渲染器可以在 `Tree` 与 `FinderView` 之间共享。

### 样式参数

```haxe
finder.rowHeight = 22;            // 行高（默认 22）
finder.iconSize = 14;             // 默认渲染器的类型图标边长（默认 14）
finder.fontSize = 13;             // 默认渲染器字号（默认 13）
finder.labelColor = 0xCCCCCC;     // 文本颜色
finder.selectionColor = 0x04395E; // 选中行背景
finder.hoverColor = 0x2A2D2E;     // 悬停行背景
finder.folderColor = 0xDCB67A;    // 文件夹图标颜色
finder.fileColor = 0x9BA5AE;      // 文件图标颜色
```

默认配色为 VSCode 暗色主题风格，浅色背景下可以自行调整。

## 数据更新

数据是 `TreeItem` 节点图，修改结构后需要调用 `refresh()` 通知刷新（与 `Tree` 的约定一致）：

```haxe
// 在当前目录中新建文件后刷新
assets.addChild(new TreeItem("maps"));
finder.refresh();

// 当前目录被移出数据源时，组件自动回到根层级
assets.parent.removeChild(assets);
finder.refresh();                  // currentItem 变回 null，派发 PATH_CHANGED
```

注意：组件不会按需加载目录内容，使用方需要预先构建好完整的 `TreeItem` 树（或在外部监听 `PATH_CHANGED` 自行填充后调用 `refresh()`）。

## 虚拟列表（大数据量）

与 `Tree`/`ListView` 一致，虚拟列表由 `layout` 的类型决定（`layout is IVirtualLayout` 时开启，`virtual` 为只读属性）。`FinderView` **默认使用 `VirtualVerticalLayout`，虚拟列表默认开启**：只会为可见区域（以及 `virtualBufferCount` 行缓冲）创建 ItemRenderer，滚动过程中自动复用 `itemRendererRecycler` 对池中的 ItemRenderer。

```haxe
finder.virtualBufferCount = 2;               // 可视区域上下额外渲染的行数

import hx.layout.VerticalLayout;
finder.layout = new VerticalLayout();        // 少量数据时可关闭虚拟列表
```

## 主要属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `data` | Array&lt;TreeItem&gt; | 数据源（根节点列表，根层级显示它的内容） |
| `currentItem` | TreeItem | 当前目录节点（`null` 表示根层级，赋值即跳转） |
| `path` | Array&lt;TreeItem&gt; | 从根到当前目录的节点链（只读，根层级为空数组） |
| `selectedItem` | TreeItem | 当前选中的主选中项（`null` 表示未选中） |
| `selectedItems` | Array&lt;TreeItem&gt; | 当前选中的全部节点（多选，保持选择顺序，只读） |
| `selectedIndex` | Int | 当前选中的行索引（-1 表示未选中） |
| `itemRendererRecycler` | DisplayObjectRecycler | 行渲染器的对象池 |
| `rowHeight` | Float | 行高，默认 `22` |
| `iconSize` | Float | 类型图标边长，默认 `14` |
| `foldersFirst` | Bool | 是否把文件夹稳定排在文件前面，默认 `false` |
| `showParentRow` | Bool | 是否在非根层级第一行显示 `..` 返回上级行，默认 `true` |
| `parentItem` | TreeItem | `..` 行对应的哨兵节点（只读） |
| `rightClickSelectEnabled` | Bool | 是否允许右键选择 |
| `virtual` | Bool | 是否为虚拟列表（只读，`layout` 为虚拟布局时自动为 `true`） |
| `virtualBufferCount` | Int | 可视区域上下额外渲染的行数，默认 `1` |

## 主要方法

| 方法 | 说明 |
|------|------|
| `goInto(item)` | 进入指定文件夹（成功返回 `true`） |
| `goUp()` | 返回上一级，并自动选中刚退出的文件夹 |
| `goToRoot()` | 回到根层级，并自动选中刚退出的文件夹 |
| `refresh()` | 数据或目录内容变化后手动通知刷新 |
| `scrollToItem(item, ?duration)` | 滚动到节点（必须在当前目录内） |
| `scrollToIndex(index, ?duration)` | 滚动到指定行 |
| `getItemAt(row)` | 获得指定行的节点 |
| `getRowOfItem(item)` | 获得节点所在的行索引（不在当前目录时为 `-1`） |
| `getItemByRenderer(child)` | 把显示对象映射为节点（用于右键菜单等自定义事件） |
| `clearSelection()` | 清除选中状态 |

## 事件

| 事件 | 说明 |
|------|------|
| `Event.CHANGE` | 选择变化 |
| `FinderView.ITEM_DOUBLE_CLICKED` | 行被双击，`event.data` 为被双击的节点 |
| `FinderView.PATH_CHANGED` | 当前目录变化，`event.data` 为新目录（根层级为 `null`） |
