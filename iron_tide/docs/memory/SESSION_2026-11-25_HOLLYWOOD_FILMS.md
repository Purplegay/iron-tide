# 洛杉矶战役原版影片

ALL02UMD.MAP 动作 100 引用 artmd.ini 的 Movies 条目 7、8、9。三者分别由 0930F29C、0932705C、05D9EE6C 触发。movmd03.mix 的 Bink 原片保留英语音轨，转成 Godot 播放的 Ogg Theora 和 Vorbis，位于 assets/ra2/hollywood。

A02_F00E 为 98.40 秒的 800×600 全屏任务影片。开场暂停模拟，结束或跳过后进入机场简报。A02_P01E 为 5 秒的回收厂通讯。A02_P02E 为 17.27 秒的片场通讯，发现克林特后播放。通讯片段沿用原始 140×110 画幅比例，以任务画中画呈现。短片结束后再触发对应的伊娃语音。

Godot 4.7.2 通过大厅任务卡进入真实战役。tests/hollywood_campaign.tscn 在 --headless --max-fps 50 下完成 25 项检查。全屏片进入播放且模拟暂停，点击跳过后恢复。回收厂短片实际播放至 finished，车队入场。发现克林特后片场短片播放，跳过有效，最终通过胜利结算。日志 %TEMP%/it-yr-film-timed.log。全屏整段实听、逐句中文字幕、影片中途冷读档和导出包仍待核验。
