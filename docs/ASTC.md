# ASTC 宏与图片加载

在 `project.xml` 注册初始化宏，源目录和运行时前缀分别对应资源的 `path` 和 `rename`：

```xml
<haxelib name="hx-astcenc" />
<haxeflag name="--macro"
    value='hx.marco.ASTCMarco.build("Assets", "assets")' />
<haxeflag name="--macro"
    value='hx.marco.ASTCMarco.build("WorldData", "worldData")' />
```

宏保留调用名 `hx.marco.ASTCMarco.build`。多次调用会合并成一份内嵌清单，整个清单进行 zlib 压缩，运行时仅解压一次。源码仍引用原来的 PNG；清单内路径自动换成同目录的 ASTC。JPG、外部头像等未列入清单的资源保持原路径。

## 构建和发布

使用 `haxelib run hxmaker build openfl html5 wechat` 或 `haxelib run hxmaker build openfl ios`。

hxmaker 会先让 OpenFL 解析本次平台条件和初始化宏，在资源扫描之前执行 ASTC 准备，再把生成目录登记为二进制资源。正式 Haxe 编译再次检查缓存，并将合并清单内嵌到游戏。直接运行 Lime/OpenFL 构建或 HXML 时，宏仍能生成纹理和清单，但不会执行 hxmaker 的资源登记准备；需要调用方提前登记生成目录。

需要先构建资源包时，执行 `haxelib run hxmaker prepare openfl html5 wechat`。它只准备资源，不编译游戏。随后运行项目自己的资源包工具，再正常构建游戏。配置只维护在项目宏中，不另建一套目录清单。

源目录 `Assets` 默认输出到 `Assets_ASTC`；目录结构不变。生成文件会登记为运行时的 `assets/**/*.astc`。项目发布工具需将输出资源目录中的独立 ASTC 上传到与原图相同的远程基址。宏不执行云端上传。

修改 hxmaker 的命令行工具源码后，需要重新生成库根目录中的 `run.n`：

```bash
cd tools
haxe tools.hxml
```

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

- `output`：独立生成目录，不允许位于源目录内部。
- `encoder`：可选的 astcenc 可执行文件路径；也可设置 `HXMAKER_ASTCENC` 环境变量。默认查找 hx-astcenc 自带工具，再查找 PATH；Windows 默认使用 SSE2 版本。
- `block`、`quality`、`alphaPremultiply`：压缩块、质量和透明预乘，默认值见上例。
- `zlib`：是否对生成的 ASTC 增加一层无损 zlib 压缩，默认 false，示例显式开启。文件扩展名和资源路径仍为 `.astc`，运行时根据二进制自动识别，无需另设加载开关。
- `zlibLevel`：zlib 压缩等级，范围为 0～9，默认 9；仅在 `zlib: true` 时生效。压缩参数参与增量缓存，切换后自动重新生成文件和清单版本。
- `strict`：为 true 时转换失败中断构建；默认排除该图并使用原资源。
- `verifyHashes`：为 true 时每次校验源图片、编码器及输出内容哈希；默认先比较时间和大小，仅变化时读取源图计算哈希。
- `force`：忽略转换缓存，强制重新编码。

编码器身份和全部编码参数参与缓存判断。输出不存在、头部/尺寸/长度不符、时间或大小改变时也会重新生成。缓存位于项目的 `.hxmaker/astc`。转换先写临时文件，通过验证后替换；失败输出不进入清单，也不会继续复用旧文件。源图删除时只清理缓存记录拥有的生成文件。

IDE 补全不执行编码。重复初始化宏的清单在当前编译的初始化阶段末尾合并，临时注册状态随即清空，避免编译服务复用旧目录配置。相同游戏路径由多个目录提供时会报错。

## 运行时

`hx.assets.ASTCManifest.resolve(originalPath)` 仅在清单命中时返回 ASTC 路径。清单异常、未命中或设备不支持 ASTC 时，继续按原图片路径加载。使用 `ASTCManifest.enabled = false` 可停用自动替换。

OpenFL 后端统一通过 `BitmapDataRequest` 加载，原图路径始终作为纹理缓存键。普通图片、XML 图集和 Spine 继续使用既有 API。显式调用 `loadBitmapData("https://.../image.astc")` 也可以加载 ASTC；显式 ASTC 地址失败时直接报告错误，不猜测 PNG 地址。

字节来源依次为资源包/原生安装包、本地缓存、微信已解压资源及远程单图。所有来源都自动识别裸 ASTC 或无预设字典的 zlib 数据；zlib 文件先读取解压后的 16 字节 ASTC 头，根据尺寸和压缩块检查预期大小，单纹理允许大小为 64 MiB，再调用平台解压器并核对实际文件头和完整长度。截断文件、错误页面、多余解压输出及解压异常都会进入原有回退流程。外层压缩只减少传输和磁盘占用，解压后仍以 ASTC 上传 GPU，不还原为 RGBA。

运行时使用 `lime.utils.Bytes.decompress(ZLIB)`：微信和 HTML5 使用现有 `pako.inflate`，原生平台使用 Lime CFFI 的 zlib。平台解压器负责压缩流和校验和验证；Lime 的整块解压接口没有输出大小限制参数，因此前后大小校验不等同于对解压期间内存的硬限制。编译宏和未提供平台解压器的调用继续使用纯 Haxe 有界解压，不依赖 Lime 或 pako。`ASTCFormat.decode` 的第三个参数允许后端注入解压函数，核心代码保持与平台解耦。

缓存路径由远程基址、清单内容版本和请求路径生成。微信使用用户目录，原生使用应用存储目录。磁盘保留下载时的裸文件或 zlib 压缩文件，读取时才解压，不额外保存解压副本。旧裸 ASTC 缓存保持兼容。远程文件设置 60 秒超时，并验证 ASTC 文件头、压缩块、尺寸和完整长度。存盘失败不影响本次已下载纹理。ASTC 失败时自动回退原图，30 秒内暂停相同 ASTC 的重复尝试。

资源包可直接收录生成的 `.astc` 文件。微信解压外层资源包后，单文件仍保持 zlib 压缩，图片加载时再自动解压；无需修改包内路径或业务层图片引用。已经发布的裸 ASTC 包需重新生成并上传才能获得压缩收益。清单按输出内容计算版本，但资源包自身的缓存版本仍需由项目发布流程管理。

内部字节加载不操作请求队列，一个图片请求最终只结算一次。下载成功不代表 GPU 创建纹理一定成功，解码异常也会触发回退。原图片也失败时，继续使用 Assets 的现有重试机制。

`Assets.loadAssetsBundle(path, true)` 可将资源包标为可选加速包。下载、解压或解析失败时继续单文件加载；默认值 false 保留旧行为。宏不会自动改变项目的资源包策略。
