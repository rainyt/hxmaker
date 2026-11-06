# 渲染稳定性验证示例

入口 Main 继承 hx.core.HxmakerApplication，业务场景在 GameStage。示例不使用游戏资源，ASTC/PNG 对照为自行生成的固定颜色样本。

## 构建

先使 hxmaker 和 hxmaker-openfl 都位于 `codex/wechat-render-stability` 分支，并确认 haxelib dev 指向它们。Haxe 编译器和标准库可通过 HAXE_BIN、HAXE_STD_PATH 覆盖；本机默认使用 `/usr/local/bin/haxe`。

在 hxmaker 仓库根目录：

```bash
# 浏览器 JS，包含可恢复 ASTC。
node samples/2d/render-stability/tools/build.mjs --astc
# 微信 JS 包，输出到 Export/wechat/html5/bin，不覆盖浏览器包。
node samples/2d/render-stability/tools/build.mjs --wechat --astc
```

不安装 hx-astcenc 时可省略 --astc。使用其他后端源码位置时设置 HXMAKER_OPENFL_SOURCE 为其 src 绝对路径。--reuse 复用已生成 HXML，只重新编译；项目 XML 变化后不要使用该参数。

微信构建会补齐适配库的原始 zygameui-dom.js 文件；不会修改生成的引擎 JS。

本机 Lime 生成器可能在已生成完整项目后报 NekoAPI 架构错误；脚本只对该已知生成器问题继续独立 Haxe 编译，真正的 Haxe 编译失败仍会退出，不修改 OpenFL/Lime。

## 自动化

启动隔离 Chrome，指定独立临时配置和 `--remote-debugging-port=9425`；在浏览器包目录启动 `python3 -m http.server 8876 --bind 127.0.0.1`。CDP_ENDPOINT 可以覆盖调试端口。

```bash
node samples/2d/render-stability/tools/run.mjs
node samples/2d/render-stability/tools/faults.mjs
python3 samples/2d/render-stability/tools/verify_images.py
node samples/2d/render-stability/tools/memory.mjs
node samples/2d/render-stability/tools/checks.mjs
```

checks.mjs 运行已编译到 bin 的索引、采样器和位图生命周期检查；对应 HXML 位于 test。结果与截图保存到 results，任何断言、未捕获异常或像素差异均判定失败。性能对照先运行 `node samples/2d/render-stability/tools/prepare-performance.mjs`，再运行 `node samples/2d/render-stability/tools/performance.mjs`。脚本从固定提交导出基线，不切换开发分支。faults.mjs 需要启用 ASTC；未启用时跳过该附加测试。memory.mjs 独立再执行 1000 轮切换并比较真实堆快照的存活对象数。

## 微信手工验收

导入 `Export/wechat/html5/bin`，使用自己的测试 AppID 和项目基础库配置。调试映射留在本地，打包配置已排除 source map 和浏览器 HTML；保留开发者工具的压缩设置。画面底部提供自动循环 200 轮、单步、安全清理、恢复测试、复制诊断按钮。未支持 WEBGL_lose_context 的环境会说明限制，不假装执行成功。

1. 检查首行红、绿、蓝、灰度、嵌套左右灰白和健康绿色块；黄色裁剪不越界。ALPHA 右半边应透明，ERASE 左半边应透明。启用 ASTC 时第二行有橙色块。
2. 自动循环 200 轮，结束画面应回到初始状态；静止十秒后点击安全清理，内容仍正确。
3. 前后台或广告返回累计 100 次，检查没有额外循环、丢图或异常；旋转、窗口变化后重复。广告流程需在实际游戏中联调，示例不接广告 SDK。
4. 环境允许时主动恢复 20 轮；不支持扩展时执行真实生命周期压力。检查图片、ASTC、文字、灰度、遮罩及离屏内容，不只检查无异常。
5. 点击复制诊断，保存构建清单和设备/系统/微信/基础库版本。分别覆盖 iOS、Android，以及项目实际支持的 iOS 高性能模式。

浏览器控制台可使用 `window.__stability.snapshot()`、`step()`、`textures(16/8/1)`、`compiled(1/8/16)`、`masks(false/true)`、`clean()`、`lose()`。故障注入 inject/feedback 仅用于诊断，应在正常流程检查之后执行。

完整接入协议见 `docs/wechat-render-stability.md`。微信真机由项目方执行，本仓库结果不会把该部分标为已通过。

ASTC 常量块布局参照 [Arm astc-encoder](https://github.com/ARM-software/astc-encoder/blob/main/Source/astcenc_symbolic_physical.cpp)；恢复注入采用 [Khronos WEBGL_lose_context](https://registry.khronos.org/webgl/extensions/WEBGL_lose_context/) 的真实丢失与恢复事件。

2026-11-06：补充 [浏览器失焦缩放回归](浏览器失焦缩放回归.md)。专项执行 resize-focus.mjs 和 verify_resize_focus.py，主压力脚本也已改为在 blur 后执行尺寸变化。
