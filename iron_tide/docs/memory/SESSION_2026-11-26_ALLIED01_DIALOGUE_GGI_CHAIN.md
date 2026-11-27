# 美国首关：三段影片对白和 GGI 后续触发

接 `SESSION_2026-11-26_ALLIED01_FOLLOWUP_FLEET_GGI.md` 与 `SESSION_2026-11-26_ALLIED01_RADIO_CAPTIONS.md`。核对 `ALL01UMD`：`0A81253C`/`0AB41D9C` 到 `0A81491C`、`0A815AFC`、`089F2AAC`。`0BF1048C` 是已有两辆 LTNK 的编组动作，V 附近零售 Units ID 0/14，ScriptType 走 22；`089F2AAC` 从 AP（41）产生 `09F3BC1C` 五名 INIT，原命令先到 14。`allied_first.gd` 用原图对象索引，不重复刷坦克；交控后提示并令其行军，随后一次性推进五步兵接近玩家区域。项目计时近似（拆链字段按现有模拟秒），原镜头、闪烁、后续步兵目标语义及自然交火未验；旧档已经过提示不会补播。

`hollywood_subtitles.gd`：从实际 A01_F00E、独立 a01_p01.wav 及 A01_P02E 取音，使用机器上已有本地 Whisper 转写，按语义校订并翻成中文（14/4/5 个字幕段）。之前 P01 . 的剧情摘要与对白不匹配：现在有桥口被毁、时光机及抢电厂警告。P01 继续按独立音轨计时，F00/P02 按影片时间。转写 SRT 在 `.validation/allied01-playable/A01_*-asr.wav.srt`；并非人工逐帧听校，开头静默和配音边界仍待窗口复核。未替换任何媒体文件。

Godot 4.7.2 隔离无头 `tests/allied_first_playable.tscn -- --extended --natural --ggi-intro` 26/26：片头首条字幕、P01 自然播放及留帧字幕继续切换、两辆原图坦克指令和新兵编组不提前、不重复。`--reported-slot2 --followup-fleet` 27/27：存档 2 副本推进穿越、P02 首句字幕、舰队回归。均 exit 0、stderr 空，日志 `.validation/allied01-playable/caption-chain-{intro,past}.{out,err}`。F00/P02 播放部分跳过；开场编组计时用夹具，不宣称自然行军到交火。未改玩家原档、未开图形窗口或打包。桥附着坍塌、DX 特殊炮击和全局 AI 生产仍未接。
