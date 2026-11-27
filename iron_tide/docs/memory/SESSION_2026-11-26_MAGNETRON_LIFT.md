# 2026-11-26｜磁电坦克抬升与空中牵引

玩家反馈只有牵引波，没有把车抬起来。先前 `head_games_weapons.gd` 用 1.5 秒地面滑移，未改变车身高度、地面占位或对空层。本轮让车辆先离地、再在空中向磁电坦克移动；停止攻击、牵引者阵亡等断链条件触发下落，落地恢复地面碰撞。既有体素绘制按 `_visual_lift()` 抬车身，阴影仍在原接触平面；磁力波端点自动读同一高度。对建筑仍用震荡副武器，不抬建筑。

零售依据：本机 Steam `rulesmd.ini` `[LocomotorBeam] IsLocomotor=yes`、Jumpjet GUID `{92612C46-F71F-11d1-AC9F-006008055BB5}`；`[JumpjetControls] CruiseHeight=500, Climb=5, Speed=14, Acceleration=2`，`Gravity=6`。SOV07 武器和地图来源见 `SESSION_2026-11-26_MAGNETRON_WAVE.md`。用 `%TEMP%/iron-yr-disasm/inspect.cjs` 对同 SHA-256 `3e81a61775d2745d1dabe397325ef663cd994ffc194da4e998e3bf5d2d308600` 的 `gamemd.exe` 复核：`0x7102BC` 后装入临时运动控制，`0x710307/0x710318` 写双方链接；`0x70FEE0` 断链接，`0x70FF13` 后依据高度分支并标记空中目标进入下落处理；`0x54C163` 后 Jumpjet 到目的点时对被牵引车辆走解除分支。未从反汇编完整还原轨迹。

实现：`scripts/units/yr_magnetron_pull.gd` 保存抬升、速度、牵引源和恢复用碰撞层；`scripts/units/head_games_weapons.gd` 启动；`scripts/units/unit.gd` 暂停地面移动、复用现有空中分层和高度，仅允许牵引自己的磁电坦克继续锁定无对空能力的目标。旧地拖存档遗留字段会清理。高桥保留项目现有桥层约束；地面不适合落地时搜索附近落点、再尝试起吊点，两者都无法落地才清除单位。这是项目防卡处理，不是原版的特殊坠落规则。

验证：Godot 4.7.2 `--headless --path <工程> --quit-after 300 res://tests/yr_magnetic_wave.tscn`，隔离 `APPDATA/LOCALAPPDATA`、隐藏窗口，从苏军菜单《首脑游戏》点击出击后在战场摆位，真实开火入口加手动推物理步，28/28、exit 0、stderr 0 字节。日志 `%TEMP%/IT-MagnetLift-1bce54ec/{out,err}.txt`。覆盖升空、目标层、波面高度、拉近、停止/失去炮手后下落、平地恢复、武器及波面回归、快照编码可校验。不代表自然游玩、图形比对、冷读档、逐桥逐坡、无落点、建筑压毁、水面沉没、原版落物伤害或发行包已验收；未改玩家存档。原版跳跃运动的细节节奏、水平插值和落点用连续空间近似，不宣称逐帧等价。
