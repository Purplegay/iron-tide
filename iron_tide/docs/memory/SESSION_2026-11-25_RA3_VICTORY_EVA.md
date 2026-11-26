# 红警3胜利播报

以 RA3 SDK 的 Sounds/Eva.xml 中 LocalPlayerVictorious 的 SideSound 和 Sounds/Voice.xml 的 Sound 为依据，从本机 Steam《起义时刻》Data/EnglishAudio.big 按 audio.manifest 的资产哈希定位 cdata，结合 audio.bin 头部用 vgmstream 解码。三条 48 kHz WAV 位于 assets/ra3/ui/victory/。

|项目阵营键|原声|秒|
|---|---|---:|
|allied|Aeva_YouAreVictorious|1.512|
|soviet|Seva_YouAreVictoriousa|1.651|
|japan|Ieva_YouAreVictorious|1.472|

BattleScreen 的胜利卡入口按玩家阵营调用 Ra2Sfx 的 EVA 播放器，并优先播报。缺少对应胜利海报时隐藏海报。升阳当前无可选军队，尤里使用现有 RA2 EVA_YouAreVictorious 查询，其当前实际音轨为盟军 ceva022.wav。

Godot 4.7.2 无头验证在场景树内调用实际胜利卡方法，以阵营夹具逐一检查四个键，播放器每次启动一次且资源路径正确，关闭 EVA 后保持静音。最终日志 %TEMP%/irontide-victory-check.log，errors=0。未跑完整对局、人工试听或导出构建。
