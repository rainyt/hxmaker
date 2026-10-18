# 天空环境示例

主视口展示高清天空、同源 IBL 金属模型及透明模型；右侧为空三维场景，借用同一张天空图片，但配置独立。两个视口都关闭自动重绘，修改天空参数时由设置检测触发刷新。应用入口继承 `HxmakerApplication`，业务逻辑在 `GameStage`。

在本目录运行：

```bash
arch -x86_64 lime test html5
```

操作：拖动主视口旋转、滚轮缩放；上方可切换天空、联动旋转、IBL、曝光与 Bloom。右侧视口用于观察共享图片的参数隔离。

内置资源为程序摄影棚，无第三方素材依赖。重新生成命令（仓库根）：

```bash
python3 tools/bake-ibl.py --output samples/3d/skybox/Assets/sky --width 32 --levels 4 --samples 32 --sky-width 512
```

正式项目可用 2048 宽度的天空和更高质量的 IBL 参数。完整接口、六面朝向、HDR 边界及生命周期见[天空环境使用说明](../../../docs/天空环境使用说明.md)。

## 自动验收

先在本目录构建：

```bash
arch -x86_64 lime build html5 -D hxmaker_skybox_checks
```

再从仓库根启动静态服务，并在另一终端运行回归：

```bash
python3 -m http.server 8732 --bind 127.0.0.1

CHROME_PATH='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' \
PLAYWRIGHT_MODULE=/usr/local/lib/node_modules/playwright \
node test/tools/run-skybox-browser.cjs
```

`HXMAKER_TEST_BASE` 可修改服务地址；`HXMAKER_TEST_REPORT` 可指定 JSON 报告路径；`HXMAKER_TEST_SCREENSHOT` 可指定截图路径。`HXMAKER_WEBGL1=1` 禁用 WebGL 2，用于 WebGL 1 路径验证。还可加入 `-D hxmaker_3d_no_vao` 构建无 VAO 路径，并设置 `HXMAKER_NO_VAO=1` 断言该路径实际启用。

回归包含核心参数、空场景、共享资源、静态重绘、相机平移及裁剪、曝光开关、普通非二次幂全景六向与接缝、旧 IBL 复用、不透明遮挡、透明合成、Bloom 和上下文恢复。GPU 验证使用软件 WebGL，不能代表真机性能。

2026-10-18：资源工具 4 项回归、WebGL 2 与 WebGL 1 无 VAO 路径各 11 组验收通过。环境与范围见[验证记录](../../../docs/天空环境验证记录-20261018.md)。
