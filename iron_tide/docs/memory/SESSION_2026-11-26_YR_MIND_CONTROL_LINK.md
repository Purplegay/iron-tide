# 2026-11-26｜尤里心控弧线

玩家指出「被控制」的连线应有弧度。旧 `yuri_support.gd::draw_control` 用固定紫色直线且始终显示。本次改为控制者房色的细抛物线和沿线移动的白色高光。普通心控刚命中无需选中便显示 20 个规则帧；之后选中控制者或受控对象可重新查看。藏线不解除控制，解除或控制者消失按现有机制撤线。迷雾仍要求两端可见；受控图标、声音、伤害、转属和过载机制未改。心灵信标和永久支配器仍按项目原先的常显条件显示，借用弧线绘制，不当成零售 CaptureManager 行为；心灵感应器预警线没改。

## 零售依据

本机 Steam `gamemd.exe` SHA-256 `3e81a61775d2745d1dabe397325ef663cd994ffc194da4e998e3bf5d2d308600`。使用 `%TEMP%/iron-yr-disasm/inspect.cjs` 核对：

- `0x471E3A` 在捕获时把规则计时赋给 ControlNode；零售 `rulesmd.ini` `[General] MindControlAttackLineFrames=20`，SOV07 无该字段覆盖。`0x472160`、`0x472640` 检查计时和对象 `isSelected`（`+0x83`），随后画线。`0x472282` 调用 `0x704E40`，颜色取控制者 House RGB。
- `0x704E40` 在三维端点间插值 32 段，Z 增量 `512*(1-((i-16)/16)^2)`，两端画小色点；`0x70519A` 用每 16 ms 一步的循环相位，`0x6612C0` 逐段将房色插值到白，不是参考重制项目里的正弦弧。受控端由 `0x472204` 加 `LeptonMindControlOffset`，类型初始化 `0x710D28` 默认 70 lepton；本机 art/rules 文件无覆盖。源端 `GetFLH(-1 - index % 5)`，零售 `artmd.ini` `[MIND]` 五组 `AlternateFLH0..4` 为 `(0,25,90),(0,-25,90),(-50,25,90),(-50,-25,90),(-25,0,90)`。

## 实装及验证

`scripts/core/yr_mind_control_link.gd` 实现弧形、房色亮纹、端点和短显示；`scripts/world/yuri_support.gd` 复用已有血条叠层入口；`scripts/units/allied_abilities.gd` 在受控目标 `special` 保存、推进和清除短显示计时。无需新存档字段，旧档没有计时则由选中重显。更新 `tests/hollywood_unit_states.gd` 的旧常显断言。

Godot 4.7.2 隐藏控制台，隔离 `APPDATA/LOCALAPPDATA`：`--headless --path <工程> --quit-after 300 res://tests/yr_mind_control_link.tscn`。实际从苏军菜单点击《首脑游戏》出击，在真实战场摆位、调用正式 `_fire_shot` 并手动推进计时；17/17、exit 0、stderr 空。覆盖抛物线、带色高光、目标跟随、暂停、重新选择、解控、精神控制车双目标、尤里改控制建筑、迷雾遮挡、快照编解码与校验。`%TEMP%/IT-MindLink-fab440be/s07.out.txt`。同一轮 `res://tests/hollywood_campaign.tscn -- --unit-states` 在旧用例的简报检查中途退出：`hollywood_campaign.gd:369` 的影片节点为 null，未进入单位断言；不计作通过。证据同目录 `hollywood.{out,err}.txt`。

未开图形窗口比对零售帧，未做冷进程读盘或出发行包。工程用 Godot 线段替代原版整数投影和 16 位光栅；普通非 MIND 载具/步兵用基点，建筑控制者用美术中心近似负槽位，受控建筑用基点加默认高度；驻车/运输状态、原版队列删除后的槽位重排及多人画面未单测。原版 SHP 心控环保留现状，不在本次连线交付范围。
