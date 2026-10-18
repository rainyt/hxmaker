# 距离雾示例

在本目录运行 `arch -x86_64 lime test html5`。拖动旋转，滚轮缩放；上方切换雾模式、天空混雾和 Bloom。天空资源借用相邻 skybox 示例的 Assets 目录。

接口、Blender 参数面板及 JSON 工作流见[距离雾使用说明](../../../docs/距离雾使用说明.md)。

验收构建：`arch -x86_64 lime build html5 -D hxmaker_fog_checks`。从仓库根启动 `python3 -m http.server 8733 --bind 127.0.0.1`，随后运行：

```bash
CHROME_PATH='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' \
PLAYWRIGHT_MODULE=/usr/local/lib/node_modules/playwright \
node test/tools/run-fog-browser.cjs
```

`HXMAKER_TEST_BASE` 可修改服务地址，`HXMAKER_TEST_REPORT` 指定 JSON 报告。加入构建宏 `hxmaker_3d_no_vao`，并设置 `HXMAKER_WEBGL1=1 HXMAKER_NO_VAO=1`，可验证 WebGL 1 的无 VAO 路径。普通构建不包含验收场景及 GPU 读回。

2026-10-19 的实际结果见[距离雾与观测站验证记录](../../../docs/距离雾与观测站验证记录-20261019.md)。
