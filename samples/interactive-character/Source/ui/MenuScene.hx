package ui;

import app.GameContext;
import hx.display.Label;

class MenuScene extends SampleScene {
	private var context:GameContext;
	private var countLabel:Label;
	public function new(context:GameContext) { super(); this.context = context; }
	override public function onStageInit():Void {
		super.onStageInit(); label("完整角色场景 · Procedure 流程整合",36,52,28,0xffffff);
		label("菜单 → Assets 加载 → 游戏 → 退出／重新加载",36,116,21);
		label("角色选择与移动、动作平滑切换、骨骼道具、跟随与环绕相机。",36,161,18);
		countLabel = action("角色数量："+context.config.characterCount,36,238,function() {
			var count = context.config.characterCount; context.config.characterCount = count == 1 ? 3 : count == 3 ? 6 : 1;
			countLabel.data = "角色数量："+context.config.characterCount;
		});
		action("进入角色场景",36,300,function() { context.requestLoading(); });
		action("演示加载失败与重试",36,360,function() { context.requestLoading(true); });
		label("故障演示会正常加载资源，再主动中止；也保留真实 Assets 错误处理。",36,421,16,0xa9bad6);
		label("底部可执行 5 轮进入／退出、重建整个流程，或将诊断 JSON 输出到日志。",36,472,16,0xa9bad6);
		label("渲染统计为运行时观察值，不替代固定设备下的性能基线。",36,515,16,0xa9bad6);
	}
}
