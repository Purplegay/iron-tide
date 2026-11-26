# 苏军第一关的简报声音和时空旋涡

截图中的对白属于 S01_P02E。零售 BIK 和现有 OGV 均为 44.1 kHz 双声道，时长分别为 30.60 和 30.61 秒。Godot 4.7.2 实播这条 OGV，三倍速下 1.8 秒墙钟推进 5.38 秒。hollywood_film.gd 将苏军第一关的四部影片按战斗倍率反向校正画面速度，用独立 AudioStreamPlayer 播放从 OGV 无损拆出的 Vorbis 音轨，原播放器静音。字幕跟随画面，跳过时停止配音。

零售 SOV01UMD 地图的 SP3.5_Enable_TimeEffect、Animation_Time Effect 和 SP4.4_Enable_TimeEffect 对应两次穿越。time_shift.gd 现在先把镜头移向时光机，time_vortex.gdshader 扭转战场，2.8 秒过程的中点替换时代，结束后再播对应的索菲亚短片。颜色、扭曲和时长是视觉近似。进度记入关卡状态。

Godot 图形窗口从苏军战役菜单出击，tests/time_shift.tscn 主流程测试工程师占领、两次旋涡先后顺序、侏罗纪存读和最终结算。测试主动推进阶段计时。--media 测试四个影片的播放、字幕和后续广播，并核对三倍速侏罗纪简报的画面进度、独立音轨进度和墙钟差均小于 0.45 秒。实机图见 evidence/SOV01_TIME_VORTEX.png。没有人工听音、原引擎逐帧画面对比、旋涡中途冷读档或发行包验证。
