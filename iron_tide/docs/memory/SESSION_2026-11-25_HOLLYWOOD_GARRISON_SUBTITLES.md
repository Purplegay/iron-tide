# 洛杉矶民房进驻与影片字幕

地图 site_types 有 55 种建筑标有 CanBeOccupied=yes。native_maps 已按原图给建筑配置容量，civilian_orders 过去仅允许 CAHSE01 在中立状态接收驻军。现在共用 civilian_garrison 判定，识别具有驻军容量的民用建筑，进驻、撤空恢复中立和工程师维修同步适用。兵种资格、容量、生命值门槛与坦克碉堡沿用各自规则。

从战役指挥室进入真实窗口，专项 tests/hollywood_campaign.tscn -- --city-house 将美国大兵放在机场附近 CAMIAM03 的可达出口，经楼体中心的战场右键指令和物理步验证进楼、归属变化、最后一人撤出。30 项通过。标准胜利 58 项通过。日志 %TEMP%/it-hollywood-house-test.log 和 it-hollywood-house-win.log。单楼实走，55 是原图类型数。

三段影片按本地 OGV 英语音轨转写并翻译，字幕时间取播放器进度。时间轴位于 scripts/ui/hollywood_subtitles.gd。长片随暂停中的影片播放，雷达短片字幕显示在主画面。P01 原声说明机场基地车，P02 介绍回收厂及居民，分别挂到机场与回收厂镜头。克林特发现时保留原有实地通讯。翻译依据英语音轨，逐字措辞与旧版中文字幕仍待对照。

## v0.32 民房撤空语音

我方最后一名驻军成功撤出、民房恢复中立时，播放 `EVA_StructureAbandoned`。单独撤出和整栋撤出共用此触发点。盟军使用 `ceva108.wav`，苏军使用 `csof108.wav`。部分撤出、出口受阻、重复撤空和敌方撤空均保持安静。

Godot 4.7.2 在隔离玩家目录运行 `tests/building_advisor_regression.tscn`。修复前两阵营共 6 项播报断言失败，修复后含新增边界检查共 58 项全部通过。两阵营撤空录音均核对了播放器资源和混音器输出。使用无头 Dummy 音频驱动，扬声器听感待实机试听。报告位于仓库根 `.validation/garrison-eva-4d204463/after/result.json`。
