# 二维渲染性能基线

该示例同时提供大量对象场景、完整帧计时、画面对照和可复现的采样工具。应用入口继承 `hx.core.HxmakerApplication`，场景逻辑位于 `GameStage`。

升级后的 `hxmaker-openfl` 默认在 GL 设备使用直接提交，无需业务开关。`baseline/` 仅包含性能对照所需的旧源码，不属于生产渲染模式；它通过单独编译生成 `baseline.js`。普通页面始终使用升级后的默认实现。

## 构建与查看

在本目录执行，需本机已安装 Haxe、OpenFL、Lime、hxmaker-openfl 及项目依赖：

```bash
node tools/build.mjs
python3 -m http.server 8765 --bind 127.0.0.1 --directory Export/html5/bin
```

已生成 OpenFL 项目文件后，可用 `node tools/build.mjs --reuse` 独立重新编译，避免重复执行项目生成工具。

打开默认直接渲染示例：

```text
http://127.0.0.1:8765/index.html?count=50000&textures=6&scenario=moving
```

打开单独编译的旧路径基线：

```text
http://127.0.0.1:8765/baseline.html?count=50000&textures=6&scenario=moving
```

参数：

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| count | 10000 | 对象数，1～100000 |
| textures | 1 | 纹理数量，1～32；超出设备批次纹理容量时自动拆批 |
| scenario | moving | 场景类型，见下表 |
| warmup | 5000 | 预热毫秒数 |
| duration | 15000 | 采样毫秒数 |
| diagnostic | 0 | 设为 1 时记录实际 GL 绘制与缓冲上传，需与正式计时分开运行 |

| 场景 | 说明 |
| --- | --- |
| moving | 全部对象移动，小对象降低填充压力 |
| partial | 每帧仅 10% 的对象移动 |
| static | 自然静止，允许保留已有渲染批次 |
| rebuild | 对象不移动，但强制重建渲染批次 |
| overlap | 大对象重叠且持续移动，用于观察填充压力 |
| correctness | 固定画面，覆盖透明度、混合、镜像、旋转、裁剪、颜色、自定义 Shader、滤镜、文字和离屏绘制 |
| cache | 与正确性场景相同，并开启整屏位图缓存 |

对象使用固定种子和固定模拟步长。计时过程中不逐帧更新文字或打印日志，完成后才显示摘要。完整结果与原始逐帧数据可从 `window.__benchmark.result`、`window.__benchmark.raw()` 读取。

## 自动采样

工具使用 Node.js 22 的内置 WebSocket 连接本地 Chrome CDP，无需 npm 依赖。请先启动使用独立临时配置目录的 Chrome，保持 HTTP 服务运行。macOS 示例：

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --remote-debugging-port=9223 \
  --user-data-dir=/private/tmp/hxmaker-benchmark-chrome \
  --no-first-run --no-default-browser-check \
  --disable-background-networking --disable-renderer-backgrounding \
  --disable-background-timer-throttling --disable-backgrounding-occluded-windows \
  --window-size=960,640 about:blank
```

本次实测没有使用 `--disable-gpu` 或强制软件渲染。环境记录中的 GPU 标识用于确认实际硬件路径。

```bash
# 正确性与静态截图，包含 5 万对象
node tools/run.mjs --suite=smoke --output=results/smoke

# 上下文恢复，以及高 DPI 的固定画面对照
node tools/run.mjs --suite=context --scenario=correctness --output=results/context
node tools/run.mjs --suite=smoke --scenario=correctness --dpr=2 --output=results/dpr2

# 1 万、5 万对象 × 1、6 张纹理，每项交替执行 5 轮
node tools/run.mjs --suite=performance --output=results/performance

# 单独记录实际 GL 绘制和上传，避免插桩影响正式耗时
node tools/run.mjs --suite=diagnostic --output=results/diagnostic
```

正式套件每次预热 3 秒、采样 7 秒。`--runs=5` 可指定重复轮数，`--scenario=correctness` 可筛选套件中的场景。默认 CDP 端口为 9223，可用 `--cdp=http://127.0.0.1:其他端口` 覆盖；HTTP 示例服务端口固定为 8765。

## 指标与判读

- `frameCpu` 包住 OpenFL 的完整帧回调，包含引擎更新、批次构建、OpenFL 显示树更新及实际渲染提交，不包含 GPU 异步完成时间。
- `update` 是示例更新循环，`build` 是主渲染器的批次构建，`render` 是 OpenFL 实际渲染。它们是完整帧的子区间，不能再与完整帧相加。
- `interval` 是相邻完整帧回调结束的间隔。报告给出均值、P50、P95、P99 和最大值。
- `diagnostic` 记录实际 GL 绘制调用、缓冲提交调用和字节数。数值型 `bufferData` 的字节量表示预留容量，非每次都有实际源数据上传；正式计时轮不启用此插桩，相应结果为 `null`。
- `gpuMs` 当前为 `null`，不把 CPU 提交时间冒充 GPU 时间。堆内存快照不等于分配量或总内存。
- 结果目录保存每轮摘要、压缩的逐帧原始数据、浏览器和 GPU 环境，以及正确性截图。
- 动态场景停止的模拟帧数会受调度影响，截图对照应使用固定画面场景；不要直接比较两轮移动场景的最终截图。

基线源码在升级前固定。为保证大数量对象确实全部绘制，两边都加入了相同的 16 位索引容量检查；基线 Render 另补一个空 `dispose()` 以兼容引擎销毁接口。这两项调整不包含直接提交、类型化数组直写或固定索引缓存优化。

## 验证边界

本次自动运行以 macOS Chrome 的 WebGL 硬件路径为准。原生 OpenGL 和各小游戏平台尚需各自运行相同回归；没有将本机结果视为所有设备的收益保证。

上下文恢复对照中，预先绘制且未保留 CPU 图像的离屏位图在两条路径中均丢失原内容；业务需要在恢复后重新绘制。这是基线已有行为，测试会保存恢复前后截图，而不会将其记成完全无损恢复。

实测结论、具体环境和数据位置见 [性能实测报告](../../docs/OpenFL二维渲染性能实测.md)。
