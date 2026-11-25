# Auto W 与技能演示

长期规则已写入项目根目录 AGENTS.md。每次新增或调整主动 W，都要同步实现自动施放及可播放的触发和效果演示。从玩家入口检查播放和等级切换。被动卡与天赋同步展示其效果。

本次十张卡已进入画廊候选，但 faction_card_stage 缺少对应绘制分支。已在 pool_research_demo.gd 添加十种时间轴示意，并在画廊按等级展示实际效果。六张主动展示 Auto W 触发场景，四张被动展示触发及结果。

Godot 无头运行 tests/pool_demo_entry.tscn，从养成界面的演示处理函数打开十张卡，切换四档、跳转时间并核对文字。输出 POOL_DEMOS_OK 40。视觉布局和成品包尚待人工验收。
本轮也补齐了船首机炮、舰载火箭排、拦截导弹和空爆子母弹的可播放演示。unit_showcase 接入 pool_talent_demo，按对应单位的天赋配置读取当前档数值。养成页沿用暂停、重播和时间轴控件。隔离运行 tests/pool_demo_entry.tscn，从养成页演示处理函数打开四个天赋并切换 0 到 3 级，输出 POOL_TALENT_DEMOS_OK 16 和 POOL_DEMOS_OK 40。验证覆盖入口、等级切换及节点状态，画面排版尚待实机核对。
