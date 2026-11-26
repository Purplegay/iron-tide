# 盖特扫射音效与快速存档复测

本机零售包提取的 hol-media-rulesmd.ini 中，YAGGUN 与 YTNK 依靠 IsGattling、Weapon1 至 Weapon6 选择三档空地武器，Report 引用 GattlingGunAttackLoop1 至 3。hol-media-soundmd.ini 第 1480 至 1512 行给出各档 Sounds 列表和 Control=attack loop random all decay、Limit=2、Volume=60/65/75。三个 Decrease 事件使用对应档最后一个录音，所查武器的 DownReport 行有分号注释。INI 支持判断事件结构，原引擎的换档时机和混音细节仍待零售实机对录。

好莱坞关 16:13:18 快速存档副本含 33 个盖特单位及建筑。自然推进 15 秒没有捕获盖特声。受控复测给一座已供电盖特建筑设置地面强制攻击目标，从专用总线捕捉 44.1 kHz 双声道。旧实现依赖 finished 主线程回调接续短片，约 15 秒内，排除初始静音，32 次内部静音超过 10ms，最长约 157ms。用原录音构建带采样点循环的三档 WAV 后仅余换档处一次约 83ms。换档时启动新声部并让旧声部短暂淡出，最终该窗口内部超过 10ms 的静音为零，采集零丢帧。此项直接测了固定建筑，车与炮共用播放实现。单位状态场景 110 项通过。

工具 tools/hollywood_gatling_loops.mjs，播放 scripts/core/gatling_audio.gd，存档场景 tests/gatling_saved_audio.tscn。采集和日志 %TEMP%/it-gatling-161318。当前持续样本按固定次序循环，各射手独立播放，尚有与零售随机控制和事件并发上限的差异。换档淡出时间为移植取值。工程改动尚未打包。