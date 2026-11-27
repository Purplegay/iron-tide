# 好莱坞右上角卡维利将军通讯字幕

- 玩家报告右上角出现一位光头角色，有原声但无中文字幕。参照 [卡维利零售片源交接](SESSION_2026-11-27_YR_SECONDARY_TEAMS_CARVILLE.md)：ALL02UMD `05D9EE6C Carville_Comment`，发现克林特后等 15 规则秒播放 `A02_P03E`。对照正片节选确认是卡维利，不是尤里。影片原声已接入，缺的是字幕表条目。
- 用本地 FFmpeg 从游戏实际加载的 `assets/ra2/hollywood/A02_P03E.ogv` 提取单声道 16kHz 原声，用本地 Whisper 转写：“Some of these Hollywood civilians are pretty tough characters, Commander. They might be able to help you.” 转写凭据 `.validation/hollywood-radio-subtitle/A02_P03E.wav.srt`。
- `scripts/ui/hollywood_subtitles.gd` 补 `A02_P03E` 的两句字幕：0–4.4 秒「卡维利：指挥官，好莱坞的平民里有几个硬汉。」；4.4–6.0 秒「他们说不定能帮上你的忙。」战场右上角雷达窗与 CG 收藏回看共用同一字幕表；未改短片、声音、触发时机、布局或存档。
- Godot 4.7.2 隐藏无头、隔离 APPDATA，运行 `--headless --path . res://tests/hollywood_campaign.tscn -- --actor-report-sale`，17/17，退出码 0，stderr 空；日志 `.validation/hollywood-radio-subtitle/godot.out`、`godot.err`。用例从正式战役菜单出击，夹具推进通讯计时，确认实际短片挂载到雷达窗、开头字幕、指定第二句时间和对白结束清空。字幕切换用指定时间检查，不是人工逐帧听校或自然播放验收。未跑有头、收藏页实际回看、存档冷读、自然全关或发行包，未改玩家存档。
