# 三倍速自动 W 与夜猎皮肤

2026-11-26。阅读 LobeHub 的 neversight-skills_feed-godot-skills 页面。页面介绍了依赖 Godot MCP 的子技能调度。本会话用本机 Godot 4.7.2 做工程验证。

- `scripts/units/auto_w.gd` 的 tick 在加速时按 delta / time_scale 递减检查计时器。0.25 秒是目标间隔，实际施放取决于物理步采样。受击记忆按模拟时间推进。三倍速短触发窗口可能错过。evaluate 单次复用卡槽与装备对象，下一次检查重新读取阵营、科技、偏好及装备。contacts 已有按物理帧分期的空间格缓存。
- `scripts/units/night_hunter_skin.gd` 保留模拟时钟和姿态更新，将材质的呼吸、灯光、尾焰上传移到绘制。每实例记录已上传时间和供电状态，物理步发起的重绘也检查屏幕可见性。复用单元素姿态数组。SCHP 五姿态、DRON 十一姿态，各 32 方向。每款首次使用时生成共享 Rect2 表，按姿态和方向索引读取。缓存属于进程内静态美术数据。
- 代码核对了谭雅与鲍里斯的挂点和星标已有缓存，英雄坦克的活动辉光经单位的重绘请求合并。此次皮肤修改范围为夜猎两款。场景内其余特殊角色和整场性能待测。
- `tests/auto_w_regression.gd` 增加三倍速下受击时间与自动检查分开推进并实际施放的断言。隔离目录回归 419 项零失败。夜猎逻辑无头 4490 项零失败。加入图集缓存后的 1280×720 OpenGL 窗口 4755 项零失败，退出 0，标准错误为空。
- 临时验证资料在 `%TEMP%/CodexIronTideValidation-3x-1126a/`。`project/probe.gd` 对 DRON 的 11 个姿态和 32 个方向循环，六轮每轮 200000 次。`before.txt` 和 `after.txt` 各轮校验和一致。中位耗时 168436.5 µs 和 34612.5 µs，差额约 0.67 µs/查询。窗口证据 `window-atlas/night-hunter-result.json`，Auto W 证据 `auto_w_regression-retry/result.json`。
- 本轮覆盖功能回归和局部 CPU 微基准。玩家实际卡顿存档的当前版本三倍速 Release 对照、整场 P95 与发布包尚待验收。旧冻结版本的慢帧记录不能用作本次基线。