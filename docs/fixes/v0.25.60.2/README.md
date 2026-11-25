# v0.25.60.2 · 英雄天赋预览重播

英雄天赋的等级选择调用 restart：时间归零、恢复播放、更新进度条／暂停按钮／说明。切换天赋原本就会重播，保留此行为；不重置用户选择的慢放速度。技能卡、普通天赋的切等级保留位置规则不变；所有进度条由用户拖动后仍保持暂停。

card_gallery_regression 共 1035 项通过，包含英雄暂停／播放时切等级归零、切天赋归零、慢放速度保留、坦克复活演示从完整 15 秒开始，以及原有其他演示回归。全程 headless，无弹窗；无脚本错误，退出仍有既有 FontAdvanced／CanvasItem／ObjectDB 释放警告。证据：C:/Users/admin/Temp/irontide-tank-heroes-20261105-133253/hero-preview-restart。未打包或推送。
