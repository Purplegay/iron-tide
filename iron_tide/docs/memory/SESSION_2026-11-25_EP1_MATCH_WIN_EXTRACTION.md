# 起义时刻胜利弹窗原声

本记录更新 SESSION_2026-11-25_UPRISING_WIN_AUDIO.md。用户指定尤里使用升阳的胜利播报和配乐。盟苏各用自己的《起义时刻》胜利原声。

起义 XML 的 PlayerTemplates.xml 指定 MatchVictoryPathMusicEvent 为 S_EndMissionWin。零售 StaticStream.big 的 static.bin 解压后，从偏移 199524 读取 PC_RA3EPPathMusicMap 的 107988 字节 MPF，配对 static/cdata/a70bc1d6.9f12cf33.2d97c0ca.a01921dd.cdata 的 Track MUS。起义 RA3Music.h 给出事件哈希 0x119F787。零售 MPF 内的 SetPlayerSoviet、SetPlayerAllied、SetPlayerJapan 分别将阵营变量 3 设为 0、1、2。按胜利事件各分支跳转并跟进入口节点，读取第一段音轨。

| 阵营 | 入口节点 | 发声节点 | vgmstream 子曲 | 样本数（44100 Hz，立体声） |
|---|---:|---:|---:|---:|
|苏军|1901|1903|749|422022|
|盟军|1904|1906|750|424330|
|升阳、尤里|2140|2142|831|469978|

vgmstream-cli -s 按上述编号解码 MPF+MUS，用 ffmpeg libmp3lame -q:a 1 转为 assets/music/ep1-match-win-{soviet,allied,japan}.mp3。使用胜利弹窗的一次性提示曲。Shell 界面另有 StatsWinTrack 事件。

改动入口为 data/music.json、scripts/core/music.gd、scripts/core/ra2_sfx.gd，更新 tests/music_regression.gd 的资源计数与结算断言。Godot 4.7.2 无头夹具依次执行 finish_battle(true) 和真实胜利卡方法，盟、苏、升阳、尤里各自的播放器资源路径和启动状态检查通过，EVA 关闭检查通过，计数 errors=0。日志 %TEMP%/it-ep1-path/verified.log。工程另有 time_shift.gd:116 的 keep_boris 类型推断错误，当前不是整包编译验收。夹具退出有资源清理提示。未进行完整对局、人工扬声器试听或导出打包。