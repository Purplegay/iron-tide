# 建筑成型音效（2026-10-23）

原有下单 `EVA_Building` 和就绪 `EVA_ConstructionComplete` 已有触发。
缺口是原版 `PlaceBuilding` 的声音素材和实际落地触发均未接入。
本机 Steam 尤复 rulesmd.ini 的 `BuildingSlam`、`BuildingDrop` 均指向该事件，
soundmd.ini 对应 `uplace`，实际长度 1.422 秒。`Construction=Dummy` 对应静音事件，
本次没有将它虚构为持续敲击或无限循环的施工声。

`ra2pipe/building_audio.py` 从已校验的本地只读 intake 导出独立候选，验证四份输入哈希、
IDX 边界和唯一样本，拒绝覆盖已有候选。最终只发布 `building_audio.json` 和
`assets/ra2/sfx/building/uplace.wav`，不重新生成单位声音或规则。
原始 IMA 数据经独立 Python audioop 解码，31359 个单声道 PCM16 样本逐字节一致。

真实建筑落地、旧式现场建造和基地车展开，通过 `_place_building` 显式开启一次声音。
预置建筑/测试夹具默认关闭；每帧动画不重播；放置失败不发声。
己方操作用全局反馈，避免宽视角或远离镜头时听不到。敌方只在己方当前可见时发声，
并保留距离衰减。声音仍走原有总音量与播放池，退出对局统一停止。
生产价格、扣费、队列、前置条件、建造时间、占地和基地车转换规则没有修改。

专项 `construction_audio_regression` 使用实际 HUD/生产/落地入口、WASAPI 混音捕获，
覆盖 RA2/扩展模式的下单、完成、落地、旧式现场施工、无效放置、预置静音、
可见/不可见敌方、远近衰减、基地车、声音自然结束、退出与再次开局。
运行命令：

```powershell
./iron_tide/tests/run-navigation-building.ps1 -Suite construction_audio_regression -RunRoot <新的外部目录>
./iron_tide/tests/run-navigation-building.ps1 -Suite structure_queue_regression -Render -RunRoot <新的外部目录>
./iron_tide/tests/run-navigation-building.ps1 -Suite base_recovery_regression -RunRoot <新的外部目录>
```

所有测试使用复制工程和独立 custom_user_dir，端口/服务/数据库为 none；不写玩家存档。
证据目录：`C:/Users/admin/Temp/iron-tide-building-audio-20261023/`。
最终同一源码 203 项通过：音频 64、实际 UI 生产队列 40、基地车与基地恢复 99。
三轮源指纹稳定，交付时逐文件复核与测试副本一致，日志无 SCRIPT ERROR/ERROR/WARNING。
汇总见外部 `delivery-audit.json`；音频使用 WASAPI，队列使用 OpenGL，基地恢复为 headless。
正式工程已执行 editor import；启动脚本直接加载源码，重开游戏即可消费更新。
自动验证证明实际 PCM 输出，听感仍待使用者确认：`pending_user_visual_confirmation`。
