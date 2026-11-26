# 洛杉矶演员应答与盖特射击声

从本机 YR 的 soundmd.ini 和 audio.idx/bag 导出 88 段 WAV。tools/hollywood_media.mjs 生成 data/ra2/hollywood_audio.json 和 assets/ra2/sfx/hollywood 下的声音文件。GameData 最后加载该音效包，CLNT、ARND、STLN 使用各自的选中、移动、攻击、受惊及死亡录音。武器沿用现有 Report 播放，三档 GattlingGunAttackLoop 音效均可解析。已撤回本轮试做的盖特升档逻辑与武器配置。

Godot 4.7.2 使用隔离 APPDATA，从任务大厅运行 tests/hollywood_campaign.tscn 加参数 --cast-media。三人的选中、移动、攻击共九项，盖特车现用武器一项、三个档位音效三项，全部成功。日志 %TEMP%/hol-audio-final.log，退出 0。验证范围为无头场景中的播放入口，实际扬声器音量和混音听感待人工试听。
