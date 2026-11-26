# 苏军第七关影像与声音

旧第七关只显示开场镜头和文字；hollywood_film.gd 的目录与全屏类型只覆盖第二关。现从本机 movmd03.mix 取四部 Bink，以 ffmpeg 转 Theora/Vorbis，全部含英语立体声音轨。Basic.Brief=S07_F00e（76.02 秒），战场 Movies 的列表序号 55/56 对应 S07_P01e（2.74 秒）和 S07_P02e（25.03 秒），Basic.PostScore=S08_F00e（99.35 秒）。全屏片暂停模拟、可跳过；两段小窗沿用雷达播放器。新开战役播放片头，读档不重播。终章在胜利玩家点击查看结算后播放一次，关闭后返回结算页。

任务广播 12 段从 evamd.ini 的 Russian、audiomd.mix 的 WAV 取得。索菲亚作战简报和后门、志愿军、联合进攻提示，尤里等待及超武挑衅，苏军 EVA 的战场控制和超武通报。探索按可见区域、联合攻势按实验室或计时，超武信息按玩家设施和难度计时适配；尚未移植完整原版超武建造和发射 AI，这些广播不能视作相应玩法已完成。城堡触发警报，志愿军有两段专有回应。场内中文提示为行动提示，未制作逐句影片中文字幕。单位及武器依据 rulesmd.ini/soundmd.ini，新增 tools/head_games_audio.mjs、共用音效样本导出函数和 data/ra2/head_games_audio.json，40 个声音事件、153 个采样。七种单位经正式 voice_id/play_voice 入口接入。

Godot 4.7.2 图形窗口 tests/head_games.tscn -- --media 共 40 项通过，含任务卡启动、暂停和跳过、雷达短片自然结束回调、21 种单位应答、12 段电台音频入播放、模拟推进基因突变器警报及胜利结算终章。日志 %TEMP%/s07-media-window.log。原战场测试 41 项通过，日志 %TEMP%/s07-media-field.log。ffmpeg 检查四部影片的音视频流。未逐句实听、未人工整局等到每个原版条件、未导出发行包。
