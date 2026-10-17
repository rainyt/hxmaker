# 角色导航与寻路

2026-10-17 接口更新：模型统一使用 `loadModel/getModel` 与 `ModelAsset`，三维节点 import 使用 `hx.display3d`；本次迁移尚未重新编译或测试。

标准 `Main → Game(Stage) → NavigationCharacterScene(Scene)` 示例。全部交互、3D 显示、加载与动画使用 hxmaker API；机器人沿用仓库生成的 GLB，通过 Assets 加载。

```bash
cd /Users/rainy/Documents/haxelib-self/rainyt/hxmaker/samples/navigation-character
arch -x86_64 lime test html5
```

顶部按钮分别演示穿门或绕墙、楼梯双向、坡道双向。行走时关闭门会禁用双向边并触发重规划；红色高台没有连接，应显示不可达。暂停保留路径，停止清空目标。Esc 停止，空格暂停或继续，失焦时暂停。左键拖动和滚轮保持原有镜头操作。

点击地面只选择附近 1.8 世界单位内、脚底高度相近的已有路点，不将任意地面点击当成自动 NavMesh 寻路。黄色点线显示本次路径，状态栏显示状态、位置、展开数与路径成本。底部可销毁并重新进入。

```bash
arch -x86_64 lime test html5 -D hxmaker_navigation_checks
```

验收宏执行真实碰撞数值断言及场景通路验收；浏览器日志出现 `HXMAKER_NAV_AGENT_CHECKS PASS` 和 `HXMAKER_NAV_SAMPLE_CHECKS PASS` 代表断言通过。普通构建不执行断言。

生命周期：先释放导航代理和图，再释放输入、相机控制器、角色控制器及碰撞体；销毁模型和显示树后释放自建几何材质，最后清理 Assets。退出会输出 `HXMAKER_NAV_RELEASE`，几何与材质引用计数应为零。

完整 API、接入要求与已知边界见[3D 导航使用说明](../../docs/3D导航使用说明.md)。
