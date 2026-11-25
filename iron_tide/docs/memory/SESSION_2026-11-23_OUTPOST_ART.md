# 一车两用前哨站贴图与维修动画

参照 refs/ts-ra2 的 Building.ts、ImageFinder.ts 和原版 art.ini、rules.ini。网页版用独立地基和体素炮塔，维修使用 SPECIAL_REPAIR_START、LOOP、END 三种状态，结束回到 IDLE。

从本机游戏 MIX 重新导出温带 CTOUTP 主体和 A/B/C/D/F 各层。将 CTOUTPBB 合入各损伤与影子帧，完整建筑健康帧增加 1846 个地基像素。机械臂使用健康/受损各自的伸出 10 帧、工作 20 帧、收回 10 帧、停放 1 帧。阵营旗单独循环。用 OUTP.VXL 导出 32 朝向的独立炮塔。重建入口为 Godot 项目下 tools/outpost_art.mjs 和仓库根目录执行 node ra2pipe/defense_art.mjs --outpost，两者均使用 RA2_MIX_DIR。

远征范围维修逐次驱动机械臂，支线标签放到建筑可见上沿。Godot 4.7.2 隔离用户目录运行 expedition_field_missions_regression.tscn，IRON_TIDE_FUEL_ONLY=1，58 项全部通过。图层姿态合成预览、日志及测试报告在 %TEMP%/CodexIronTideValidationOutpostArt/。当前固定温带素材。合成预览覆盖三种姿态，防空实射、玩家存档和发行包未验收。
