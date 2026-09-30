# Tree — 树形列表

本文档介绍 `Tree`（树形列表）组件，以及配套的 `TreeItem`（数据节点）与 `TreeItemRenderer`（默认行渲染器）。

`Tree` 继承自 `Scroll`，是一个类似 VSCode 资源管理器的树形列表组件，支持展开/折叠、选择、悬停高亮、滚动定位，并且与 `ListView` 一样支持**虚拟列表**，可以承载成千上万个节点。

## 基本用法

```haxe
import hx.display.Tree;
import hx.display.TreeItem;
import hx.events.Event;

var tree = new Tree();
tree.width = 260;
tree.height = 400;
tree.x = 50;
tree.y = 50;

// 通过 TreeItem 构造树，第二个参数是子节点列表，第三个参数是初始展开状态
var main = new TreeItem("Main.hx");
var src = new TreeItem("src", [main, new TreeItem("Player.hx")], true);
var treeData = [
    src,
    new TreeItem("assets", [new TreeItem("hero.png")]),
    new TreeItem("project.hxml")
];
tree.data = treeData;

// 监听选择变化
tree.addEventListener(Event.CHANGE, function(event) {
    trace("选中了：" + tree.selectedItem.label);
});

this.addChild(tree);
```

`children` 为 `null` 或空数组的节点是叶子节点（没有展开箭头），存在子节点的节点是文件夹节点。

## 展开/折叠

```haxe
tree.expandItem(src);              // 展开节点
tree.expandItem(src, true);        // 展开节点及其全部后代
tree.collapseItem(src);            // 折叠节点
tree.toggleItem(src);              // 切换展开状态
tree.isItemExpanded(src);          // 是否处于展开状态
tree.expandAll();                  // 展开全部
tree.collapseAll();                // 折叠全部
```

也可以通过 `TreeItem.expanded` 属性声明初始展开状态。展开/折叠时会派发 `Tree.ITEM_EXPANDED` / `Tree.ITEM_COLLAPSED` 事件，`event.data` 为对应的节点，可用于持久化展开状态。

## 选择

```haxe
tree.selectedItem = main;          // 按节点选择
tree.selectedIndex = 2;            // 按可见行索引选择
tree.clearSelection();             // 清除选择
```

- 选择变化时派发 `Event.CHANGE`（与 `ListView` 一致）
- `selectedIndex` 是**可见行**的扁平索引，展开状态变化后会自动跟随选中项偏移
- 选中项的祖先被折叠时，选中项保持不变（行暂时不可见），再次展开祖先即可恢复显示
- 被移除出树的选中项会在 `refresh()` 后自动清除

### 多选（Ctrl/Shift + 点击）

与 VSCode 资源管理器一致的交互行为：

| 操作 | 行为 |
|------|------|
| 点击 | 只选中该行 |
| `Ctrl`/`Cmd` + 点击 | 切换该节点的选中状态（追加/移除多选） |
| `Shift` + 点击 | 选中锚点到当前行的区间（替换整个选择） |
| `Ctrl`/`Cmd` + `Shift` + 点击 | 把区间追加到当前选择 |
| 右键点击 | 只把未选中的节点改为单选，已选中的保留多选（配合右键菜单） |

带修饰键的点击只改变选择，不会触发文件夹的展开/折叠。范围选择的**锚点**是最近一次普通点击或 `Ctrl`+点击的行，`Shift`+点击不会移动锚点，因此可以在同一锚点上反复扩展区间。

多选结果通过 `selectedItems` 读取（保持选择的先后顺序）：

```haxe
tree.addEventListener(Event.CHANGE, function(event) {
    trace('选中 ${tree.selectedItems.length} 项');
    trace('主选中项：' + tree.selectedItem.label);
});
```

`selectedItem` 是最后交互的**主选中项**，它始终在 `selectedItems` 中（`Ctrl`+点击取消主选中项时，会转移到最近一次选中的节点）。

### 交互行为

交互行为与 VSCode 资源管理器一致：

- 点击展开箭头（twisty）：只切换展开状态，不改变选择
- 点击行：选中该行；点击文件夹行时默认同时切换展开状态（可通过 `toggleFolderOnClick = false` 关闭）
- 右键点击：默认也会选中（可通过 `rightClickSelectEnabled = false` 关闭），配合自定义右键菜单使用

## 滚动定位

```haxe
// 让节点可见，祖先被折叠时会自动展开祖先（类似 VSCode 的 reveal）
tree.scrollToItem(main);
tree.scrollToItem(main, 0);        // 立即定位，不带缓动

// 按可见行索引滚动（与 ListView.scrollToIndex 一致）
tree.scrollToIndex(100);
```

## 自定义行渲染器

默认渲染器 `TreeItemRenderer` 提供选中/悬停背景、展开箭头与文本展示。需要图标或更复杂的展示时继承它：

```haxe
import hx.display.TreeItemRenderer;
import hx.display.TreeRowData;
import hx.display.Image;

class FileItemRenderer extends TreeItemRenderer {
    var icon:Image;

    override function onInit():Void {
        super.onInit();
        icon = new Image();
        icon.y = 3;
        // 放在箭头与文本之间
        this.addChildAt(icon, 1);
    }

    override function setData(value:Dynamic):Void {
        super.setData(value);
        var row:TreeRowData = value;   // item 为节点，depth 为层级深度
        icon.data = UIManager.getBitmapData(row.item.isFolder ? "icon_folder" : "icon_file");
        // 文本位置由父类按缩进维护，图标跟随文本即可
        icon.x = this.label.x;
        this.label.x += icon.width + 4;
    }
}

tree.itemRendererRecycler = new DisplayObjectRecycler(FileItemRenderer);
```

渲染器的 `data` 是 `TreeRowData` 结构：

| 字段 | 类型 | 说明 |
|------|------|------|
| `item` | TreeItem | 行对应的树节点 |
| `depth` | Int | 层级深度，根节点为 `0` |

缩进、展开箭头与选中/悬停背景由 `TreeItemRenderer` 自动维护，子类只需要处理自定义内容。

### 样式参数

```haxe
tree.rowHeight = 22;              // 行高（默认 22）
tree.indent = 16;                 // 每级缩进（默认 16）
tree.twistySize = 16;             // 展开箭头热区宽度（默认 16）
tree.fontSize = 13;               // 默认渲染器字号（默认 13）
tree.labelColor = 0xCCCCCC;       // 文本颜色
tree.selectionColor = 0x04395E;   // 选中行背景
tree.hoverColor = 0x2A2D2E;       // 悬停行背景
tree.twistyColor = 0xCCCCCC;      // 展开箭头颜色
```

默认配色为 VSCode 暗色主题风格，浅色背景下可以自行调整。

## 数据更新

树的数据是 `TreeItem` 节点图。修改结构后需要调用 `refresh()` 通知树刷新：

```haxe
// 通过 API 增删节点
var newFile = new TreeItem("Enemy.hx");
src.addChild(newFile);
tree.refresh();

// 直接修改 children 数组同样需要 refresh()
src.children.push(newFile);
tree.refresh();

// 替换整个数据源
tree.data = [newData];
```

## 虚拟列表（大数据量）

与 `ListView` 一致，虚拟列表由 `layout` 的类型决定（`layout is IVirtualLayout` 时开启，`virtual` 为只读属性）。`Tree` **默认使用 `VirtualVerticalLayout`，虚拟列表默认开启**：只会为可见区域（以及 `virtualBufferCount` 行缓冲）创建 ItemRenderer，没有被渲染的行区域由布局的占位对象支撑滚动范围，滚动过程中自动复用 `itemRendererRecycler` 对象池中的 ItemRenderer。

```haxe
var tree = new Tree();                    // 默认即虚拟列表，行高 22
tree.virtualBufferCount = 2;              // 可视区域上下额外渲染的行数
tree.data = hugeTree;                     // 上万个节点也可以流畅滚动
```

行高通过 `rowHeight` 调整，虚拟模式下会自动同步到 `VirtualVerticalLayout` 的 `itemSize`；也可以在创建布局时指定：

```haxe
import hx.layout.VirtualVerticalLayout;

tree.layout = new VirtualVerticalLayout(30);   // 行高 30 的虚拟列表
```

少量数据时可以切换为普通模式（全部行都创建 ItemRenderer）：

```haxe
import hx.layout.VerticalLayout;

tree.layout = new VerticalLayout();       // 关闭虚拟列表
```

### 虚拟列表注意事项

- 每个 ItemRenderer 的位置与占位对象由虚拟布局负责，`Tree` 只负责创建、回收与数据绑定
- `virtual` 是只读属性，由 `layout` 的类型自动决定，不需要也不允许手动开启
- 请保证行渲染器的实际高度不超过 `rowHeight`，否则相邻的行会重叠
- 虚拟模式下 `children` 中会额外存在一个占位对象（布局的 `spacer`，空容器不产生绘制开销），请不要把 `children` 直接当作数据行来遍历
- `virtualBufferCount` 是可视区域上下额外渲染的行数

## 主要属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `data` | Array&lt;TreeItem&gt; | 树数据源（根节点列表） |
| `selectedItem` | TreeItem | 当前选中的主选中项（最后交互的节点，`null` 表示未选中） |
| `selectedItems` | Array&lt;TreeItem&gt; | 当前选中的全部节点（多选，保持选择顺序，只读） |
| `selectedIndex` | Int | 当前选中的可见行索引（-1 表示未选中） |
| `itemRendererRecycler` | DisplayObjectRecycler | 行渲染器的对象池 |
| `rowHeight` | Float | 行高，默认 `22` |
| `indent` | Float | 每级缩进尺寸，默认 `16` |
| `twistySize` | Float | 展开箭头热区宽度，默认 `16` |
| `virtual` | Bool | 是否为虚拟列表（只读，`layout` 为虚拟布局时自动为 `true`） |
| `virtualBufferCount` | Int | 可视区域上下额外渲染的行数，默认 `1` |
| `toggleFolderOnClick` | Bool | 点击文件夹行时是否同时切换展开状态，默认 `true` |
| `rightClickSelectEnabled` | Bool | 是否允许右键选择 |

## 主要方法

| 方法 | 说明 |
|------|------|
| `refresh()` | 数据或展开状态变化后手动通知刷新 |
| `expandItem(item, ?recursive)` / `collapseItem(item, ?recursive)` | 展开/折叠节点 |
| `toggleItem(item)` | 切换节点展开状态 |
| `expandAll()` / `collapseAll()` | 展开/折叠全部节点 |
| `isItemExpanded(item)` | 节点是否处于展开状态 |
| `scrollToItem(item, ?duration)` | 滚动到节点（自动展开祖先） |
| `scrollToIndex(index, ?duration)` | 滚动到指定可见行 |
| `getItemAt(row)` | 获得指定行的节点 |
| `getRowOfItem(item)` | 获得节点所在的行索引（不可见时为 `-1`） |
| `getItemByRenderer(child)` | 把显示对象映射为节点（用于右键菜单、双击等自定义事件） |
| `clearSelection()` | 清除选中状态 |
