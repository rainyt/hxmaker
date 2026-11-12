# ASTC 纹理

ASTC 是一种 GPU 压缩纹理格式。Hxmaker 在**构建期**把 PNG 编码为 ASTC，并把生成结果写入一份内嵌清单；**运行时**根据清单把 `.png` 请求替换为同路径的 `.astc`，直接上传 GPU，不做 RGBA 解码。

相比 PNG/RGBA 纹理，ASTC 的主要收益：

- GPU 显存占用约为 RGBA8888 的 1/9（6x6 块约 0.44 字节/像素）
- 省去运行时 PNG 解码，加载更快
- 可选的 zlib 外层压缩能进一步降低下载与磁盘占用

资源代码仍然引用原来的 PNG，业务层不需要改路径。

---

## 环境准备

ASTC 需要三部分配合：

| 组件 | 作用 |
|------|------|
| `hxmaker` | 构建宏、清单、运行时加载器 |
| `hxmaker-openfl` | OpenFL 后端的纹理上传实现（`hx.core.ASTCDecoder`） |
| `hx-astcenc` | `astcenc` 编码器与 `openfl.display.ASTCBitmapData` |

`project.xml` 中同时引入库并打开运行时开关：

```xml
<haxelib name="hx-astcenc" />
<haxedef name="hx_astcenc" />
```

缺少 `hx_astcenc` 定义时，运行时的 ASTC 代码不会被编译，清单即使生成也不会生效。

编码器按以下顺序查找：

1. `ASTCMarco.build` 的 `encoder` 选项
2. 环境变量 `HXMAKER_ASTCENC`
3. `hx-astcenc` 库自带工具目录
4. 系统 `PATH`（Windows 默认使用 SSE2 版本）

---

## 项目配置

在 `project.xml` 注册初始化宏。第一个参数是源目录，第二个参数是运行时前缀，对应 `<assets>` 的 `rename`：

```xml
<haxeflag name="--macro"
    value='hx.marco.ASTCMarco.build("Assets", "assets")' />
<haxeflag name="--macro"
    value='hx.marco.ASTCMarco.build("WorldData", "worldData")' />
```

多个目录会合并成一份清单。生成文件默认输出到源目录旁的 `Assets_ASTC`，目录结构保持不变。

源码中继续写 `assets/ui/panel.png`，运行时会自动请求 `assets/ui/panel.astc`。

---

## 构建与发布

### 使用 hxmaker CLI（推荐）

```bash
haxelib run hxmaker build openfl html5 wechat ./MyGame
```

`hxmaker build` 会在 OpenFL 扫描资源之前自动执行 ASTC 准备，把生成目录登记为二进制资源，然后正常编译并内嵌清单。**不需要手动执行 prepare。**

### 先构建资源包的流水线

资源包工具需要在编译前拿到 ASTC 文件时，先单独准备资源：

```bash
haxelib run hxmaker prepare openfl html5 wechat ./MyGame
# 此时 Assets_ASTC 已生成，运行项目的资源包工具
haxelib run hxmaker build openfl html5 wechat ./MyGame
```

`prepare` 只生成资源，不编译游戏。

### 直接使用 HXML 或 openfl 命令

宏在编译时仍会生成 `.astc` 和清单，但 OpenFL 的资源扫描发生在宏执行之前，不会自动登记生成目录。需要手动登记：

```xml
<assets path="Assets_ASTC" rename="assets" include="*.astc" type="binary" embed="false" />
```

或者把 `Assets_ASTC` 上传到 CDN / 打进项目自己的资源包。

> 注意：运行时清单一旦命中就只认 ASTC。如果生成目录既没有登记也没有上传，加载会直接报错，不会回退 PNG。

### 发布要求

- 生成的 `.astc` 必须上传到与原图相同的远程基址，目录结构保持一致。
- 清单版本由输出内容计算，但资源包自身的缓存版本仍由项目发布流程管理。
- 修改 `tools/` 下的 CLI 源码后，需要重新生成 `run.n`：

```bash
cd tools
haxe tools.hxml
```

---

## 编码配置

```haxe
hx.marco.ASTCMarco.build("Assets", "assets", {
    output: "Assets_ASTC",
    block: "6x6",
    quality: "-exhaustive",
    alphaPremultiply: true,
    zlib: true,
    zlibLevel: 9,
    strict: false,
    verifyHashes: false,
    force: false
});
```

| 选项 | 默认值 | 说明 |
|------|--------|------|
| `output` | 源目录 + `_ASTC` | 独立输出目录，不允许位于源目录内部 |
| `encoder` | 自动查找 | astcenc 可执行文件路径 |
| `block` | `6x6` | 压缩块，支持 4x4 ～ 12x12 的合法组合 |
| `quality` | `-exhaustive` | `-fastest` ～ `-exhaustive` |
| `alphaPremultiply` | `true` | 透明预乘 |
| `zlib` | `false` | 对 ASTC 增加一层无损 zlib 压缩，扩展名仍为 `.astc` |
| `zlibLevel` | `9` | 0～9，仅在 `zlib: true` 时生效 |
| `strict` | `false` | 为 true 时编码失败中断构建 |
| `verifyHashes` | `false` | 深度校验源图、编码器与输出内容，耗时更高 |
| `force` | `false` | 忽略缓存强制重新编码 |

修改 `encoder`、`block`、`quality`、`alphaPremultiply`、`zlib` 或 `zlibLevel` 后，建议用 `force: true` 刷新一次已有输出。

### 增量与缓存

缓存位于项目的 `.hxmaker/astc`。默认只按源图修改时间判断是否复用：

- 全部命中缓存时不查找编码器，也不读取 PNG 内容
- 源图修改时间变化、缓存缺失或输出文件缺失时重新编码
- 保留修改时间的替换、已有输出损坏不会被发现，用 `force` 或 `verifyHashes` 处理

转换失败的单张图片会被排除出清单并保留原图；只有 `strict: true` 才会中断构建。编码器完全不可用时编译仍可继续，只是所有图片都走原图。

---

## 运行时行为

图片请求按固定顺序分发：

1. **资源包优先**：资源包里提供了这张位图就直接使用；包内位图解码失败时继续下一步。
2. **清单命中且设备支持 ASTC**：请求同路径的 `.astc`，读取字节后直接上传 GPU。
3. **原图**：清单未命中或设备不支持 ASTC，沿用原来的 PNG/JPG 流程。

`BitmapDataFuture` 在进入图片请求队列之前先判断资源包：如果已加载的资源包提供了对应原图（`UIManager.hasBytesByBundle`，只查条目不解压），就直接使用包内位图；否则再按清单走 ASTC。

清单命中的资源优先使用 ASTC，失败时默认回退原图：

- 字节下载失败、文件损坏、GPU 上传失败时记录警告并回退原图，同一资源 30 秒内不再重复尝试
- 设备不支持 ASTC 属于分发条件，不是加载失败，直接走原图
- 需要严格模式（失败即失败）时，编译时定义 `hx_astc_strict`

### 显式 ASTC 地址

```haxe
assets.loadBitmapData("assets/ui/panel.astc");
```

显式 `.astc` 直接按 ASTC 加载；失败时报告错误，不猜测 PNG 地址。

### 字节来源

ASTC 的判定在 `hx.core.BitmapDataFuture.post()` 里完成，先于图片请求入队；命中时只发起字节请求：

1. 资源包内存数据
2. 微信小游戏本地已解压文件
3. 远程单图

下载默认 60 秒超时；压缩字节在上传后立即归还缓存引用。

### 运行时开关

```haxe
hx.assets.astc.ASTCManifest.enabled = false;
```

可全局停用清单替换，作为紧急回退到原图的手段。

### 资源包优先的取舍

资源包按文件名匹配。如果包里同时存在 `foo.png` 和 `foo.astc`，会使用 PNG。希望走 ASTC 时，请让资源包对清单命中的资源只收录 `.astc`。

---

## 后端接入

核心只依赖 `hx.assets.astc.IASTCDecoder` 接口：

| 方法 | 说明 |
|------|------|
| `isSupported()` | 当前设备与渲染上下文是否支持 ASTC |
| `fromBytes(bytes)` | 把校验过的字节上传为 GPU 压缩纹理 |
| `inflate(bytes)` | 外层 zlib 解压，平台无优化实现时返回纯 Haxe 结果即可 |

OpenFL 后端的实现是 `hx.core.ASTCDecoder`，在第一次加载图片时自动注册。其他后端在加载资源前调用：

```haxe
hx.assets.astc.ASTCLoader.registerDecoder(new MyASTCDecoder());
```

`registerDecoder` 可以重复调用，便于替换实现或在测试中注入桩。

### 核心 API

| API | 说明 |
|-----|------|
| `ASTCLoader.canLoad(url)` | 只判断该路径是否需要走 ASTC，不产生请求 |
| `ASTCLoader.load(url, callback)` | 返回 `false` 表示与 ASTC 无关；返回 `true` 表示已接管，成功或失败只回调一次 |
| `ASTCLoader.registerDecoder(decoder)` | 绑定后端解码器 |
| `ASTCLoader.timeoutMilliseconds` | 字节等待超时，默认 60000 |
| `ASTCLoader.maxBytes` | 解压后允许的最大字节数，默认 64 MiB |
| `ASTCManifest.resolve(path)` | 清单命中时返回 ASTC 路径，保留 `?query` / `#hash` |
| `ASTCManifest.getVersion()` | 清单内容版本，可用于隔离缓存 |

---

## 常见问题

**纹理没有替换成 ASTC**

依次检查：`hx_astcenc` 定义是否打开、宏是否注册、清单前缀与 `rename` 是否一致、生成目录是否登记或上传、设备是否支持 ASTC。

**构建提示"找不到 ASTC 编码器"**

安装 `hx-astcenc`，或设置 `HXMAKER_ASTCENC`，或在宏配置里指定 `encoder`。非 `strict` 模式下构建不会中断，只是该图使用原图。

**HXML 直编后运行时报 ASTC 加载失败**

HXML 构建不会执行资源登记。手动添加 `<assets ... include="*.astc" .../>`，或把生成目录上传/打进资源包。

**修改 zlib 或块尺寸后没有变化**

缓存默认只看源图修改时间。用 `force: true` 重新编码一次。

**资源包里同时有 PNG 和 ASTC，但一直用 PNG**

资源包优先是设计行为。清单命中的资源只收录 `.astc` 即可。

**想临时关闭 ASTC**

设置 `ASTCManifest.enabled = false`，或移除 `hx_astcenc` 定义后重新编译。
