# 第一关返回旧金山后五人无法移动（2026-11-26）

## 玩家现象和依据

用户截图：苏军第一关《时空转移》返回旧金山后，基地旁的鲍里斯与四辆重型坦克无法移动。实际使用玩家 `slot3.itsave` 的只读副本冷进程加载；原档 SHA-256 `BA2D5CF15B6FDA98953A206A509C6B0338C0979A197EFC83A95D6404FFB4BAF3`，检查后不变。存档是 `yr_time_shift` 的 phase 4，61 单位、258 建筑；五人已有移动命令，非眩晕、装载或米格冷却故障。

零售 SOV01UMD.MAP 的本工程导出 `data/maps/yr_sov01.json` 中 `local_size=[4,5,54,132]`，第 71 号航点是返回时代的苏军基地。五人出生位置的原图地形掩码都是可走陆地 `raw=1`，但阶段边界 `time_shift.gd::BOUNDS[2]` 原为 `Rect2i(4,11,53,78)`，截止纵向 89 格；五人对应的区域纵坐标约 90.5–92.5，落在边界外。`PathService.native_flags` 先以边界返回 0，`Unit._domain_ok` 因而拒绝移动。隔离测试单步、解除暂停后真实物理推进均重现五人零速度。最初一次未解除 SceneTree 暂停的复现不能作为故障证据，已排除。

## 实际修改

`scripts/world/time_shift.gd` 仅将第四阶段 `BOUNDS[2]` 高度从 78 改为 126，纵向终点到 137，覆盖原图 local_size 下缘和基地及道路。不改其他两个时代边界，也不绕开原版逐格水域、岩石和坡地的地形掩码。该文件在当前工作区原已未跟踪，本轮只动该行，未清理其他未提交修改。新增 `tests/boris_slot3_hang_probe.gd/.tscn` 作为存档副本冷读回归，要求 `IRON_SAVE` 指向副本、隔离 APPDATA 带 `IronTideSlot3Hang`；运行时只拷贝到隔离的 slot1。

## 验证

Godot 4.7.2 headless，隔离 `%TEMP%/IronTideSlot3Hang-20261126`：冷读原存档副本后五人出生格 `native_flags=1`、`_domain_ok=true`，目标处原图岩石仍 `native_flags=4`；五人移动命令生效，三秒物理时间后各自离开原位超过 20 世界单位。`result.json` 5/5，exit 0，stderr 空。原有关卡 `tests/time_shift.tscn` 主链 49/49，exit 0，stderr 空，含第二次转场、接管基地与摧毁控制器结算。日志 `regression.txt`、`time_shift.txt` 同目录。原档未改动，不需改写存档，更新脚本后重新读取即可。

未逐格验证扩展边界中的全部路段、原版游戏的相同时刻移动轨迹、图形窗口从玩家点击到目标的操作、冷进程存档再保存或独立打包版。
