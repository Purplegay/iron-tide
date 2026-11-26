# 索敌回归：合成伞降夹具不参与绘制（2026-11-26）

- `.validation/target-scan-reuse/test-err.log` 记录旧错误：`Unit._draw` → `_draw_pose` → `american_paradrop.gd::draw_chute` 读取缺失的 `special.para_age`。本夹具只用 `para_height` 测试索敌是否读取实时空中状态，不是完整伞降对象；正式伞降生成流程负责初始化动画字段。未改生产代码或存档。
- `tests/target_scan_reuse_regression.gd` 保留入树前禁用处理并隐藏夹具，保留索敌使用的场景组；新增绘制信号计数，等待两个 `process_frame` 后断言没有绘制回调，避免测试过早退出掩盖问题。
- 证据 `.validation/target-scan-reuse/fixture-20261126-155219/`：用 B1 冻结项目副本、当前测试、隔离用户目录和 Godot 4.7.2/OpenGL 跑真实场景。`hidden` 退出 0，25/25，日志无脚本错误；`visible-control` 只在副本去掉 `hide()`，退出 1，复现同一个 `para_age` 错误并触发新增的绘制断言。随后恢复副本夹具。
- 此轮是针对绘制错误的功能验证，不是性能 A/B，不提供帧时收益结论；未跑完整战场或正式伞降动画回归。
