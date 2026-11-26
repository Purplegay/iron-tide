# 鲍里斯空袭指针

选中鲍里斯并指向可攻击的敌方建筑，显示原版旋转空袭准星。指向敌军地面单位显示普通攻击指针。光标表示下达攻击命令的方式，空袭冷却由战斗代码处理。

`scripts/ui/battle_cursor.gd` 的 attack_cursor 和动画资源表接入 `assets/ra2/cursors/boris_airstrike.png`。Flare 在 rulesmd 规则导出中设有 MigAttackCursor=yes。Steam 尤复 gamemd.exe 的光标表项 0x52 对应起始帧 480、帧数 8、间隔 4 游戏帧，居中热点。素材提取自 ra2md.mix 内 conqmd.mix 的 MOUSE.SHA，使用 MOUSEPAL.PAL，尺寸 55×43，热点 (27,21)。

Godot 4.7.2 独立用户目录运行 tests/cursor_regression.tscn，两种模式合计 78/78 通过，退出码 0，标准错误为空。测试在实际战场悬停敌方电厂，验证动画换帧、素材和单位目标指针。图像通过 SubViewport 获取，桌面系统鼠标由已有 Windows 路径安装。报告和两种模式截图在 %TEMP%/IronTideBorisCursor1125/。
