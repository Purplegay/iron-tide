# v0.25.60.1 · 调节进度后保持暂停

用户操作演示进度条时立即暂停，松开后不恢复之前的播放状态。点击同一位置不发生数值变化也保持暂停；键盘调整进度同样暂停。按钮立即显示“继续”，仅显式继续／重播才能恢复。适用于共用 demo_playback 的技能卡、原生天赋、专属天赋和英雄天赋演示。

用户 seek 与程序定位分开：每帧进度同步不触发暂停；切等级的 restore_position 仍保留原来的播放／暂停状态和时刻。

验证：card_gallery_regression 1032 项通过，覆盖拖动后再推进时间仍冻结、继续按钮恢复、直接修改滑条值暂停、未移动点击暂停、慢放、切等级、重播及演示只读性。全程 headless，无弹窗。无脚本错误；退出存在原有 FontAdvanced／CanvasItem／ObjectDB 释放警告。证据：C:/Users/admin/Temp/irontide-tank-heroes-20261105-133253/timeline-stay-paused。未打包或推送。
