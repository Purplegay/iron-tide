# 美国首关开场雷达简报字幕

用户截图为 A01_P01E 雷达小窗有画面但底部无字幕。原播放器已经以独立 `a01_p01.wav` 计时（3 秒画面、约 13.99 秒音频），根因是 `scripts/ui/hollywood_subtitles.gd` 未登记 A01_P01E。现补 0–4.4、4.4–9.1、9.1–14.1 三段中文战场简报要点；不是英语原声逐句核译。没有改音频、场景、暂停和存档。

Godot 4.7.2 隐藏无头、隔离 APPDATA，`tests/allied_first_playable.tscn -- --extended --natural` 27/27、exit 0、stderr 空：实际菜单出击，跳过全屏片头，雷达简报自然播，验证开始有字幕、第 6 秒已定格但原声推进且字幕已切换、自然归还操作。日志 `.validation/allied01-playable/subtitle-a01.{out,err}`。未开图形窗口、未改玩家档。全屏 A01_F00E、穿越后 A01_P02E 的逐句字幕仍未做，不能算整关字幕验收。
