# 滚动与列表

本文档介绍 `Scroll`（滚动容器）和 `ListView`（列表视图）两个组件。

## Scroll — 滚动容器

`Scroll` 是一个带遮罩的滚动容器。通过裁剪可视区域，内部的子对象可以滚动查看。支持水平和垂直方向的滚动，以及惯性滑动效果。

### 基本用法

```haxe
import hx.display.Scroll;

var scroll = new Scroll();
scroll.x = 100;
scroll.y = 50;
scroll.width = 400;    // 可视区域宽度
scroll.height = 300;   // 可视区域高度

// 添加内容（内容可以超出可视区域）
for (i in 0...20) {
    var quad = new Quad(380, 80, 0x6699CC);
    quad.y = i * 90;
    scroll.addChild(quad);
}

this.addChild(scroll);
```

### 背景设置

```haxe
var scroll = new Scroll();
// 设置背景颜色
scroll.backgroundColor = 0xEEEEEE;
// 设置背景透明度
scroll.backgroundAlpha = 0.5;
```

### 滚动属性

```haxe
// 获取或设置滚动位置
scroll.scrollX = 100;  // 水平滚动到 100px
scroll.scrollY = 200;  // 垂直滚动到 200px
```

### 橡皮筋效果

Scroll 默认开启橡皮筋效果（overscroll），滚动超出边界时会产生弹性拉扯，松手后自动弹回：

```haxe
// 创建时指定是否启用 overscroll（默认 true）
var scroll = new Scroll(true);

// 或直接设置
scroll.isOverScrollEnabled = true;
```

滚动超出边界时使用 Actuate 动画平滑弹回。

### 滚动条

Scroll 内置了水平和垂直滚动条支持：

```haxe
// 访问滚动条
scroll.vScrollBar;  // 垂直滚动条
scroll.hScrollBar;  // 水平滚动条
```

滚动条会在内容超出可视区域时自动显示，支持拖拽操作。

### 主要属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `scrollX` | Float | 水平滚动偏移 |
| `scrollY` | Float | 垂直滚动偏移 |
| `backgroundColor` | Int | 背景颜色 |
| `backgroundAlpha` | Float | 背景透明度 |
| `isOverScrollEnabled` | Bool | 是否启用橡皮筋效果 |
| `vScrollBar` | IScrollBar | 垂直滚动条 |
| `hScrollBar` | IScrollBar | 水平滚动条 |

## ListView — 列表视图

`ListView` 继承自 `Scroll`，是一个数据驱动的列表组件，支持 ItemRenderer 回收复用，适合大量数据的列表展示。

### 基本用法

```haxe
import hx.display.ListView;
import hx.display.ArrayCollection;

var listView = new ListView();
listView.width = 400;
listView.height = 500;
listView.x = 50;
listView.y = 50;

// 设置数据源
listView.data = new ArrayCollection(["选项一", "选项二", "选项三", "选项四", "选项五"]);

// 监听选择事件
listView.addEventListener(Event.CHANGE, function(event) {
    trace("选中了：" + listView.selectedIndex);
    trace("选中项：" + listView.selectedItem);
});

this.addChild(listView);
```

### 自定义 ItemRenderer

默认的 ItemRenderer 使用 `Label` 显示文本数据。你可以创建自定义的 ItemRenderer：

```haxe
import hx.display.ItemRenderer;

class MyItemRenderer extends ItemRenderer {
    var icon:Image;
    var label:Label;

    override function onInit():Void {
        super.onInit();
        icon = new Image();
        icon.y = 5;
        this.addChild(icon);

        label = new Label();
        label.x = 60;
        label.y = 10;
        label.fontSize = 20;
        this.addChild(label);
    }

    override function set_data(value:Dynamic):Dynamic {
        super.set_data(value);
        // value 是数据源中的一项
        icon.data = UIManager.getBitmapData(value.icon);
        label.text = value.name;
        return value;
    }

    override function set_selected(value:Bool):Bool {
        super.set_selected(value);
        this.alpha = value ? 1.0 : 0.6;
        return value;
    }
}
```

使用自定义 ItemRenderer：

```haxe
var listView = new ListView();
listView.itemRendererRecycler = new DisplayObjectRecycler(MyItemRenderer);

// 设置复杂数据
listView.data = new ArrayCollection([
    {icon: "icon_sword", name: "长剑"},
    {icon: "icon_shield", name: "盾牌"},
    {icon: "icon_potion", name: "药水"},
]);
```

### 所有数据更新

数据变化后手动通知刷新：

```haxe
// 修改数据后刷新列表
listView.data.source.push(newItem);
listView.updateAllData();
```

### 选择切换的音效

```haxe
listView.changedSoundId = "click_sound";  // 切换选择时播放音效
```

### 右键选择

```haxe
listView.rightClickSelectEnabled = false;  // 禁用右键选择
```

### 默认垂直布局

ListView 默认使用垂直布局（`VerticalLayout`），子项从上到下排列。如果你需要水平布局，可以手动修改：

```haxe
listView.layout = new HorizontalLayout();
```

### 虚拟列表（大数据量）

当数据量达到成千上万条时，为每一条数据都创建 ItemRenderer 会带来巨大的创建开销和渲染开销。把 `layout` 设置为**虚拟布局**（实现了 `hx.layout.IVirtualLayout` 的布局）即可开启虚拟列表：ListView 只创建**可见区域**（以及缓冲）内的 ItemRenderer，没有被渲染的数据区域由布局的占位对象支撑滚动范围，滚动过程中会自动复用 `itemRendererRecycler` 对象池中的 ItemRenderer。

```haxe
import hx.layout.VirtualVerticalLayout;

var listView = new ListView();
listView.width = 400;
listView.height = 500;

// 使用虚拟纵向布局，并指定每个 Item 的高度（必须大于 0）
listView.layout = new VirtualVerticalLayout(80);

// 上万条数据也可以流畅滑动
listView.data = new ArrayCollection(bigDataArray);

this.addChild(listView);
```

横向列表使用 `VirtualHorizontalLayout`，参数为每个 Item 的宽度：

```haxe
import hx.layout.VirtualHorizontalLayout;

listView.layout = new VirtualHorizontalLayout(120);
```

虚拟布局与普通布局一样支持间距、填充与对齐参数：

```haxe
var layout = new VirtualVerticalLayout(80);
layout.gap = 10;                  // Item 间距
layout.horizontalFill = true;     // Item 宽度撑满列表
layout.horizontalAlign = CENTER;  // 水平对齐
listView.layout = layout;
```

滚动到指定数据索引（虚拟列表与普通列表都可用）：

```haxe
listView.scrollToIndex(5000);        // 带缓动
listView.scrollToIndex(5000, 0);     // 立即定位
```

### 虚拟列表注意事项

- `virtual` 是只读属性，由 `layout` 的类型自动决定（`layout is IVirtualLayout`），不需要也不允许手动开启
- 每个 Item 的尺寸是固定的（`VirtualVerticalLayout` 为高度、`VirtualHorizontalLayout` 为宽度），必须大于 `0`
- 请保证 ItemRenderer 的实际高度（宽度）不超过布局的 `itemSize`，否则相邻的 Item 会重叠
- Item 的位置由虚拟布局负责（按数据索引排列），`children` 中会额外存在一个占位对象（`layout.spacer`，空容器不产生绘制开销），请不要把 `children` 直接当作数据项来遍历
- 数据变化后同样需要调用 `updateAllData()` 才会刷新
- 需要自定义虚拟布局时，实现 `IVirtualLayout` 接口：用 `slotSize` 提供槽位尺寸、`horizontal` 提供主轴方向、`spacer` 提供占位对象，并在 `getVisibleRange()` 中返回可见区间、在 `setItems()`/`update()` 中按数据索引排列 Item

### 主要属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `data` | ArrayCollection | 列表数据源 |
| `selectedIndex` | Int | 当前选中的索引（-1 表示未选中） |
| `selectedItem` | Dynamic | 当前选中的数据项（只读） |
| `itemRendererRecycler` | DisplayObjectRecycler | Item 渲染器的对象池 |
| `changedSoundId` | String | 选择切换音效 ID |
| `rightClickSelectEnabled` | Bool | 是否允许右键选择 |
| `virtual` | Bool | 是否为虚拟列表（只读，`layout` 为虚拟布局时自动为 `true`） |
| `virtualBufferCount` | Int | 可见区域上下（左右）额外渲染的 Item 数量，默认 `1` |

### ArrayCollection

`ArrayCollection` 是数组数据的封装：

```haxe
var collection = new ArrayCollection([1, 2, 3]);

// 获取原始数组
var arr = collection.source;

// 修改后刷新列表
arr.push(4);
listView.updateAllData();

// 重新设置数据
listView.data = new ArrayCollection(["新数据"]);
```
