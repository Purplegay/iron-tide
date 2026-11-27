# 《脑死》6 号档复现基因突变器底座消失

- 玩家截图中基因突变器 `YAGNTC` 倒计时约 3:44，只显示细长关盖部件及投影；上方是心灵控制器 `YAPPET`。两座图层不能按同一规则判断：原版关盖 `YAGNTC_E` 健康帧只包含局部，`YAGNTC.png` 才有宽底座；`YAPPET_E` 的关盖帧本身有完整底座。原版来源沿用 [闪烁修正](SESSION_2026-11-26_YURI_SUPERWEAPON_FLICKER.md) 和 [提前开盖](SESSION_2026-11-27_YURI_SUPERWEAPON_LIDS.md) 的零售 SHP 记录。
- 原版关卡为 `ALL07SMD`，游戏存档任务 `yr_allied_finale`。只复制 `slot6.itsave` 到 `%TEMP%/IronTide-Slot6-Yuri-20261127/profile`，SHA-256 `32CBC8DBDEDCB9DD74F12029952E42733D54B681A6B2532CA00A717427FBDBC4`。Godot 4.7.2 隐藏无头独立进程，通过正式 `BattleSaves.load_into_scene("slot6")` 冷读并恢复战场。基因突变器满血、可见、充能已归零，正走 `superanimthree`，实际取 `YAGNTC_F` 帧 20，含底座；故不宣称原档一加载就出现截图症状。
- 仅在隔离战场内存把该建筑剩余充能调回 224 游戏秒（截图的 3:44），不写档。使用与正式绘制共享 `_draw_ra2_sprite` 的 `fog_pose()` 抓取绘图命令：只提交了 `YAGNTC_E` 帧 0 和配对投影，不提交主体。原始帧非透明区域仅 34×58；导出裁帧与实际主体、已就绪帧目视对照，关盖时缺底座，与截图一致。当前 `building.gd::_uses_full_superweapon_pose()` 把所有已落成的尤里超武状态都视为完整姿态，导致 `_draw_ra2_sprite()` 在关盖阶段也跳过主体和主体投影；只保留局部关盖层。
- 证据 `%TEMP%/IronTide-Slot6-Yuri-20261127/`：`baseline2.out`、`stages.out`（退出 0、stderr 空）、`mutator-{body,224,0}.png`、探针 `.gd/.tscn`。先行探针生命周期有误而超时，修正为 `tree.current_scene = null` 后完成冷读；不以超时结果作证。未打开图形窗口、未做完整战场截图、未改生产代码或玩家存档，未打包。后续修复要分别验两座建筑在健康/受损、待机/打开/收盖的实际像素覆盖，不能只断言“完整姿态不叠主体”。

## 修复与复验

- `scripts/buildings/building.gd` 仅将 `YAGNTC` 已落成的待机关盖姿态作为局部覆盖：绘制现有健康/受损主体、`YAGNTC_E` 盖子及其原版投影，不额外生成圆影。点击判定同时看主体和可见盖子像素。`YAGNTC_F/H` 开盖、待发、收盖仍用完整姿态，不双画底座；`YAPPET` 不变。不重烘贴图，不改充能、伤害或存档格式。
- 隐藏无头隔离：`res://tests/yr_superweapon_idle_art.tscn` 89/89，覆盖满血/受损、关盖合成、突出盖子点击、提前开盖、双倍图、待发、实际发射与回待机。通过正式入口重新冷读 6 号档，原档时间点仍绘制完整开盖姿态；仅在内存调回 224 游戏秒，修后绘图命令在原有盖子和原版投影之外补上宽 156 的主体图层。两组均退出 0、stderr 空；日志见同目录 `final-{regression,slot6}.{out,err}`。未开有头窗口、未构建发行包。
