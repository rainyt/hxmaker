# ASTC 宏与图片加载

在 `project.xml` 注册初始化宏，源目录和运行时前缀分别对应资源的 `path` 和 `rename`：

```xml
<haxelib name="hx-astcenc" />
<haxedef name="hx_astcenc" />
<haxeflag name="--macro"
    value='hx.marco.ASTCMarco.build("Assets", "assets")' />
<haxeflag name="--macro"
    value='hx.marco.ASTCMarco.build("WorldData", "worldData")' />
```

`hx_astcenc` 用于启用运行时加载代码，`hx-astcenc` 库提供编码器与 `openfl.display.ASTCBitmapData`。两者缺一不可。

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
- `zlibLevel`：zlib 压缩等级，范围为 0～9，默认 9；仅在 `zlib: true` 时生效。修改后需使用 `force: true` 刷新已有输出。
- `strict`：为 true 时转换失败中断构建；默认排除该图并使用原资源。
- `verifyHashes`：默认为 false，仅按源图修改时间判断是否更新。为 true 时执行深度检查，校验源图片、编码器及输出内容哈希，并校验输出格式和尺寸；该模式会增加编译耗时。
- `force`：忽略转换缓存，强制重新编码。修改编码器、`block`、`quality`、`alphaPremultiply`、`zlib` 或 `zlibLevel` 后，使用 `force: true` 刷新一次，再恢复为 false。

默认优先保证增量编译速度：源图的 `mtime` 与缓存一致且输出文件存在时，直接复用缓存记录和清单版本，不比较源图大小，不读取 PNG 文件头，不读取或解压已有 ASTC，也不检查输出修改时间、大小和编码参数。全部命中缓存时不查找编码器。源图修改时间变化、缓存缺失或输出文件缺失时重新生成；即使源图内容相同，只要修改时间变化也会重新编码。保留修改时间的内容替换及已有输出损坏不会被默认模式发现，可使用 `force: true` 重建或开启 `verifyHashes` 深度检查。

缓存位于项目的 `.hxmaker/astc`，兼容已有缓存，无需全量重新生成。新转换仍先写临时文件，通过格式、尺寸和长度验证后替换；失败输出不进入清单，也不会继续复用旧文件。源图删除时只清理缓存记录拥有的生成文件。

编码器不可用时只输出提示并保留原图，编译不会中断；只有 `strict: true` 才会让构建失败。IDE 补全不执行编码。重复初始化宏的清单在当前编译的初始化阶段末尾合并，临时注册状态随即清空，避免编译服务复用旧目录配置。相同游戏路径由多个目录提供时会报错。

## 运行时

图片请求按下面的顺序分发：

1. **资源包优先**：资源包里提供了这张位图就直接使用。包内位图解码失败时继续下一步。
2. **清单命中且设备支持 ASTC**：把 `.png` 请求替换为同路径的 `.astc`，由 `hx.assets.astc.ASTCLoader` 读取并直接上传为 GPU 压缩纹理。
3. **原图**：清单未命中或设备不支持 ASTC 时，沿用原来的 PNG/JPG 加载流程。

清单是构建期生成的权威信息，**命中即视为该资源只提供 ASTC**：字节下载失败、文件损坏或 GPU 上传失败都会直接回报加载错误，不再回退原图。这样发布问题会立刻暴露，而不是悄悄使用旧 PNG。设备不支持 ASTC 属于分发条件，不是加载失败，仍走原图。

## 后端接入

核心只依赖 `hx.assets.astc.IASTCDecoder` 接口，不直接引用平台类型：

- `isSupported()`：当前设备与渲染上下文是否支持 ASTC。
- `fromBytes(bytes)`：把校验过的 ASTC 字节上传为 GPU 压缩纹理。
- `inflate(bytes)`：ASTC 外层 zlib 解压，平台无优化实现时返回纯 Haxe 解压结果即可。

OpenFL 后端的实现是 `hx.core.ASTCDecoder`，在第一次加载图片时自动注册。其他后端在加载资源前调用：

```haxe
hx.assets.astc.ASTCLoader.registerDecoder(new MyASTCDecoder());
```

`ASTCLoader.registerDecoder` 可以重复调用，便于替换实现或在测试中注入桩。

`hx.assets.astc.ASTCLoader` 的行为约定：

- 返回 `false` 表示该路径与 ASTC 无关，调用方继续原图流程，不会收到回调。
- 返回 `true` 表示已接管，成功或失败都只回调一次。
- 显式 `.astc` 地址直接按 ASTC 加载；失败时报告错误，不猜测 PNG 地址。
- 字节来源复用现有 `BytesFuture`：资源包、微信本地文件、远程单图。
- 默认 60 秒超时；压缩字节在上传后立即归还缓存引用。
- `ASTCManifest.enabled = false` 可停用自动替换，作为紧急回退到原图的手段。

资源包内的路径按文件名匹配。由于资源包优先，如果包里同时存在 `foo.png` 和 `foo.astc`，会使用 PNG；希望走 ASTC 时，请让资源包对清单命中的资源只收录 `.astc`。

旧的「无清单、微信本地已解压 `.astc`」加载方式已移除，所有 ASTC 资源都需要通过宏清单生效。

资源包可直接收录生成的 `.astc` 文件。微信解压外层资源包后，单文件仍保持 zlib 压缩，图片加载时再自动解压；无需修改包内路径或业务层图片引用。已经发布的裸 ASTC 包需重新生成并上传才能获得压缩收益。清单按输出内容计算版本，但资源包自身的缓存版本仍需由项目发布流程管理。

ASTC 的字节请求复用现有 `BytesFuture` 管线，会占用一个请求队列位置；外层图片请求无论成功还是失败都只结算一次。原图也失败时，继续使用 Assets 的现有错误处理机制。
