# 盖特机炮与盖特坦克射击节奏

YAGGUN 使用 hollywood_yuri.json。原版 rulesmd.ini 的六把枪都含 Burst=2，导出器此前丢掉该字段。现已补齐数据及导出，并在 building.gd 按首发起算装填，沿用车辆默认 0.1 秒连发间隔，同目标有效时补射第二发。YTNK 来自 hollywood_cast.json，普通及精英枪已有两连发。对地各档原版 ROF 均为 16，升档会切换弹头。对空三档 ROF 为 16、8、4。

原版 soundmd.ini 的三个 Report 都有 attack loop random all decay。新增 gatling_audio.gd，每个射手使用自己的播放器，首段起转，从中间片段随机续播，末段收尾。

Godot 4.7.2 隔离 APPDATA，tests/hollywood_campaign.tscn -- --unit-states，104 项通过，退出 0。增加固定炮装填期间射出两枚弹丸、车炮独立播放器、中段及尾段选择的回归。日志位于 %TEMP%/it-gatling-regression/console.log。无头运行验证播放状态与片段选择，实际扬声器听感待试听，组内间隔沿用项目默认值。未打包。
