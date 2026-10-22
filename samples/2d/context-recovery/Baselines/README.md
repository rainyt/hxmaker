# 二维恢复实测记录

[首轮原始报告](2026-10-16-first-failed.json) 来自用户提供的 `hxmaker-2d-recovery-1792139642961.json`。

- Safari，报告版本 1，主动丢失/恢复 1 轮。
- 浏览器恢复事件、设备代次、后端完成次数均为 1；lost=false、pending=false、errors 为空。
- 人工记录 passed=false，用户明确反馈文字仍不显示。
- 此报告说明恢复入口执行完成，不能证明文字图集已经正确生成和上传；不能记为恢复通过。

本轮后续补充 BitmapData 离屏渲染器重建和恢复后的 CPU 字形图集，并增加报告版本 2 的文字诊断。保留此失败报告供后续对照。

## 修补后的用户实测

[通过报告](2026-10-16-passed.json) 来自 `hxmaker-2d-recovery-1792140311028.json`。用户确认“测试正确”。本次由助手读取报告并归档，没有重新构建或运行测试。

- Safari，报告版本 2，浏览器恢复事件、设备代次和后端完成次数均为 4；最终 lost=false、pending=false，errors 为空。
- 最终人工记录 passed=true，对应第 4 轮；用户在对话中确认本轮测试正确。
- 11 个驻留文本全部 prepared，pending=0、stale=0；始终为 1 张图集、108 个字形。
- 首次恢复时 cpuPixels 从 false 变为 true，glyphWrites 从 108 增至 216，完成一次新图集生成。第 2、3 轮恢复后 glyphWrites 保持 216，文字布局继续准备，符合复用 CPU 像素的实现。
- 第 3 轮后手动重建过一次图集：请求瞬间 pending=11、stale=11、atlasCount=0，这是重建请求后的中间状态；下一份快照已恢复为 prepared=11、pending/stale=0，glyphWrites 增至 324。
- 第 4 轮恢复后 glyphWrites 仍为 324，最终人工确认通过。文字代次为 5，比设备代次 4 多 1，来源于这次手动重建。

结论：本轮 Safari 纯二维静态恢复及手动图集重建得到用户验证。当前报告没有像素自动断言、内存采样或性能数据，不能据此量化 CPU 图集的内存和性能影响；二维/三维混合恢复仍应在混合示例独立记录。
