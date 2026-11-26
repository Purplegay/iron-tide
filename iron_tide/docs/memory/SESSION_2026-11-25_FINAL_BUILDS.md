# 远征终章构筑扩容

远征共 30 关。用户希望在已有装备和羁绊全满后继续获得不同打法。第 26 关起开放接力突袭，第 28 关起开放围攻小队，均沿用 3、6、9 层机制。第 26 至 30 关每关把一件新的三级战术装备加入奖励与商店候选。前线拨款令增加开战资金，军需议价函降低刷新费用。新内容沿用现有远征存档字段。已生成的奖励在下一次生成时才会抽新内容。

改动位于 scripts/expedition 的 army、trait_progression、catalog、market、rules、relics、runtime。另在 native_maps.gd 显式声明 campaign_art 为 bool，解决 Godot 4.7.2 的静态推断错误。

Godot 4.7.2 无头真实场景采用单独用户目录。tests/expedition_final_builds.tscn 通过 34 项，包括逐关填满此前装备、羁绊后检查可选项，领取与读档，换目标、追击、集中三击和装备组合。tests/expedition_relics_regression.tscn 通过 706 项，商店遍历测试移到第 30 关以覆盖完整藏品池。运行日志位于 %TEMP%/CodexIronTideValidation-FinalBuilds-1125a/final.log 和 relics.log。未连续实玩五关、量测构筑胜率或制作发布包。
