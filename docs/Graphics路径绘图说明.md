# Graphics 路径绘图

`hx.display.Graphics` 负责提交绘图，路径、样式、命令和几何数据统一位于 `hx.display.graphics` 包。现有 OpenFL 后端继续消费三角形命令，无需增加渲染接口。

## 快速使用

```haxe
import hx.display.Graphics;
import hx.display.graphics.GraphicsPath;
import hx.display.graphics.GraphicsStrokeStyle;

var graphics = new Graphics();
var path = new GraphicsPath();
path.moveTo(20, 80);
path.bezierCurveTo(20, 10, 120, 10, 120, 80);
path.lineTo(70, 130);
path.closePath();

graphics.fillPath(path, 0x4488ff, 0.6);
graphics.strokePath(path, 0xffffff, 3, 1, new GraphicsStrokeStyle(ROUND, ROUND));
addChild(graphics);
```

路径方法返回自身，可以链式调用。`GraphicsPath.clear()` 清空路径命令，`clone()` 复制路径，均不会修改已经提交的图形。

## 路径方法

| 方法 | 作用 |
| --- | --- |
| `moveTo(x, y)` | 开始新子路径 |
| `lineTo(x, y)` | 添加直线；空路径上等价于移动起点 |
| `quadraticCurveTo(cx, cy, x, y)` | 添加二次贝塞尔曲线 |
| `bezierCurveTo(cx1, cy1, cx2, cy2, x, y)` | 添加三次贝塞尔曲线 |
| `arc(x, y, radius, startAngle, endAngle, anticlockwise)` | 添加圆弧，角度单位为弧度 |
| `closePath()` | 闭合当前子路径 |

绘制贝塞尔曲线前必须先指定起点。圆弧会从当前点连接到圆弧起点；没有当前点时直接以圆弧起点开始。

默认圆弧方向在屏幕坐标中为顺时针；设置 `anticlockwise=true` 改为逆时针。起止角差的绝对值达到一周时绘制完整圆。零角差和零半径不生成圆弧，但仍会移动或连接到其起点。

`closePath()` 后继续添加线或曲线，会从已闭合轮廓的起点开始新的开放轮廓。填充时开放轮廓隐式闭合；描边只在显式闭合时连接首尾。

## 填充

```haxe
graphics.fillPath(path, color, alpha, tolerance);
```

- 支持顺时针和逆时针的简单凸、凹多边形。
- 支持同一路径中多个相互分离的填充轮廓。
- 暂不支持孔洞、嵌套轮廓、自交、轮廓之间相交或接触。这些情况会报错，且不会向 `Graphics` 留下部分绘制命令。
- 零面积轮廓、空路径和不足三个有效点的轮廓不生成填充。
- 首版路径填充为纯色；位图三角形、矩形及实心圆仍使用 `beginBitmapData()`。线段、折线和圆形描边使用独立的纯色描边，不采样当前填充位图。

细小的重复边和共线点会按数值容差清理。接近浮点数精度极限的轮廓不保证保留全部细节。

## 描边

```haxe
import hx.display.graphics.GraphicsLineCap;
import hx.display.graphics.GraphicsLineJoin;

var style = new GraphicsStrokeStyle(
    GraphicsLineCap.ROUND,
    GraphicsLineJoin.MITER,
    4
);
graphics.strokePath(path, 0xffffff, 8, 0.5, style, 0.25);
```

| 设置 | 选项 | 默认值 |
| --- | --- | --- |
| `cap` | `BUTT` 平头、`SQUARE` 方头、`ROUND` 圆头 | `BUTT` |
| `join` | `MITER` 斜接、`BEVEL` 削角、`ROUND` 圆角 | `MITER` |
| `miterLimit` | 斜接长度与半线宽的最大比值，至少为 1 | `4` |

闭合路径不使用端点样式。斜接超过限制时退化为削角。普通相邻线段使用共享截面，减少半透明转角重复覆盖；短线段会限制内侧交点，避免数值尖刺。

路径自交、完全折返，以及线宽大于局部空间的情况仍可能形成重叠，重叠区域按正常透明度混合，不进行描边布尔并集。完全折返的连接采用平头退化处理。

## 精度、缓存与限制

`tolerance` 是本地坐标中的细分误差，默认 `0.25`，必须是正有限数值。曲线采用自适应细分，圆弧依据弦高误差细分。放大图形时，可使用更小的误差重新提交。

路径缓存当前误差下的轮廓、填充网格和最近一组描边几何。同一条路径以不同颜色提交时可复用网格；修改路径后只会影响后续提交。描边样式在提交时读取，后续修改样式对象不会污染已提交网格。

为限制复杂度，当前设置以下上限，超出时明确报错：

- 单条路径最多 16384 条命令。
- 细分后最多 16384 个轮廓点，贝塞尔递归深度最多 16 层。
- 单次填充最多 2048 个细分点，使用简单多边形耳切三角化。
- 单份路径网格最多 65535 个顶点。

曲线细分解决轮廓精度；像素边缘的平滑由下面的覆盖率抗锯齿单独处理。目前没有增加渐变、完整 SVG 解析、孔洞或自交填充。

## 边缘覆盖抗锯齿

```haxe
graphics.antialiasing = true; // 默认开启，可直接切换已有图形
graphics.antialiasWidth = 1; // 最终物理屏幕像素，允许范围为 (0, 4]
```

`fillPath()`、`strokePath()`、`drawLine()`、`drawLines()`、`drawCircleLine()` 和连续 `lineTo()` 使用路径网格命令，默认开启边缘覆盖抗锯齿。`drawTriangles()`、位图矩形、普通 `drawRect()` 和 `drawCircle()` 保留原有三角形提交行为，不自动处理轮廓。

该方案不生成位图、不新增离屏纹理、不修改着色器。OpenFL 后端将已有三角形网格的重复顶点焊接后，提取仅属于一个三角形的轮廓边；内部公共边不生成过渡带。描边的内外边缘、端点和转角均由相同的边界规则处理。

基础网格覆盖率为 1，外侧过渡顶点覆盖率为 0。后端通过已有的顶点透明度通道传递：

```text
顶点透明度 = 对象世界透明度 × 本次绘制透明度 × 顶点覆盖率
```

现有着色器对透明度进行插值，并同步衰减预乘颜色和透明度。所有顶点仍提交到原有合批缓冲区，不为过渡带单独创建绘制对象。

过渡宽度根据显示树、后端根容器的缩放/旋转以及设备像素比换算，支持非等比缩放和镜像。缓存只依赖线性变换和过渡宽度，单纯平移会复用网格；增量 `lineTo()` 会使过渡缓存失效。

首版采用**向外过渡**，不内缩基础网格。布局尺寸和命中范围保持原始几何边界，但视觉边缘会略向外柔化，极细线可能显得增厚。可以用 `0.5`、`1`、`2` 三档过渡宽度比较效果；这不是带亚像素线宽补偿的精确面积覆盖算法。尖角过渡偏移限制为过渡宽度的四倍。

变换接近奇异、网格边界无法形成单一连接，或者追加过渡顶点会超过 65535 顶点限制时，安全回退为原始硬边网格。自交、相互覆盖和很窄的凹槽不进行布尔并集，过渡带可能相互叠加。紧贴轮廓的自定义裁剪或离屏缓存需要预留过渡带空间。

必须同时使用已接入 `DRAW_PATH` 的 `hxmaker-openfl` 后端。实际改动位于后端的 `src/hx/render/ImageBufferData.hx`：先解析路径网格，再复用原有三角形与透明度写入流程。已有 `DRAW_TRIANGLE` 命令签名保持不变；自行消费绘图命令的其他后端需要增加 `DRAW_PATH` 分支。

## 原有接口的行为修正

- 多次绘制的边界合并计算，并只统计索引实际引用的顶点。
- 绘制、清空和手动失效会通知舞台刷新、当前对象滤镜及父容器布局。
- `clear()` 同时重置填充、线宽、描边颜色、画笔位置和渲染游标。
- `beginLineStyle()` 设置独立描边，不再隐式更改填充；没有显式描边颜色时，沿用当前纯色填充，默认黑色。
- `drawLines()` 和 `drawCircleLine()` 正确传递透明度和颜色变换。
- `drawLines(points, alpha, color, closed)` 新增末尾可选参数 `closed`，默认 `true`，保留原有闭合行为。基础形状和点集绘制不移动 `moveTo()/lineTo()` 的画笔。
- 连续同样式 `lineTo()` 共用一份网格，并增量更新最后一个转角；`smoothing=true` 使用削角，`false` 使用受限斜接。修改样式、透明度或插入其他绘图会开始新的描边段。
- 矩形允许负宽高，零尺寸跳过；负半径、负线宽、非法坐标、无效索引或不足的 UV 会报错。透明度必须有限，并限制到 `[0, 1]`。
- 未指定填充时，直接提交三角形或基础填充形状使用白色材质，避免依赖上帧残留状态。

`fillPath()` 和 `strokePath()` 使用显式颜色，不改变 `beginFill()`、`beginBitmapData()` 或描边颜色。它们会结束当前旧式连续折线段，但不移动画笔。

低层 `drawTriangles()` 保留顶点、索引、UV 和显式颜色变换的引用，以兼容动态网格。修改这些数据后应保持索引和数组有效，并调用 `graphics.invalidate()` 更新缓存和刷新通知。不要把这种低层借用引用语义与路径的提交快照语义混用。

原 `hx.display.GraphicsDrawData` 及其 `Draw` 类型保留兼容别名，实际实现已移到 `hx.display.graphics.GraphicsDrawData`。

## 测试示例

参见 `samples/graphics/README.md`。示例启动类继承 `hx.core.HxmakerApplication`，场景由 `GameStage` 管理。视觉示例、手绘和 20 项回归检查均已提供；这些示例不代表已经执行验证。
