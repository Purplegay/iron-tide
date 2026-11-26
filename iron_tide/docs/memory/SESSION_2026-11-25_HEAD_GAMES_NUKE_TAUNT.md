# 首脑游戏核弹井与铁幕建成时的尤里广播

原图 On-nuke silo / On-Iron Curtain 为玩家事件 19 的建筑索引 54/24；随后三种解放状态触发动作 21，语音 Mis_xS7_YuriSuperweapons 对应 xs7yu01.wav。普通和困难有效，两个基地都已解放时不播。此次将既有语音从轮询建筑所有权改到 battle.strategic_site_completed 的实际落成路径，沿用 head_super_start 存档标志去重。地图预置、俘获以及盟军超武不再误触发。

Godot 4.7.2 真实第七关场景 tests/head_games.tscn -- --nuke-voice 19 项通过。含准备好后的正式落成、播放文件路径和播放器状态、重复通知、三种难度与四种解放状态。日志 %TEMP%/s07-nuke-interaction.log。未实等生产倒计时或打包。
