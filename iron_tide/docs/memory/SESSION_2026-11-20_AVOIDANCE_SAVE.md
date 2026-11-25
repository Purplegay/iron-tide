# 2026-11-20 远征避障反馈与存档备份

用户截图：远征4/30，基地建筑密集处容易卡住；要求复制远征存档用于排查。

## 已完成
- 原档：C:/Users/admin/AppData/Roaming/Godot/app_userdata/Iron Tide RTS/expedition.itrung。
- 备份：C:/Users/admin/IronTide/.validation/expedition-avoidance-20261120-122001/expedition.itrung。
- 2094140字节；复制前原档、复制后原档、备份SHA256一致：3AC38F6565F953837164CB4DB02AEF000C65BE7A16D3DB67D0A48AA54A55399F。
- 独立最小Godot项目只读解析副本：phase=battle，stage=4，route=尤复 · 不屈战区，checkpoint存在；1508 records，34建筑、73单位。
- 解析脚本与summary.log在上述备份目录。注意脚本path_size只识别Array，不识别PackedVector2Array，因此输出path_size=0不构成路径为空的证据。
- 当前副本盟军密集群多数has_move_order=false；仅瞬态存档不能证明长期卡死或其根因。
- 隔离工程：C:/Users/admin/IronTide/.validation/avoidance-regression-20261120-1220/project；自定义用户目录CodexIronTideValidation/7e2d77b5fd314527a25aa0283d87b150。
- fresh import复制/导入阶段初次命令120s超时，随后单独完成editor导入；import-error.log空，import.log首行错误计数0（大量内容为正常资产导入进度，不是错误）。
- 第一次直接运行遗漏IRON_TIDE_REPORT_DIR，被测试保护拒绝，未进入用例；项目自定义目录实际已经设置，不是缺自定义目录。
- 补报告环境变量重跑真实navigation_building_regression.tscn：exit0，REGRESSION checks=42 failed=0。reports/runtime-console.log及result.json保存证据。

## 边界与下一步
- 本轮无生产代码改动，无玩家存档写回，无游戏进程停止。
- 已存在大量并行未提交改动，包括foundation_transit.gd、local_traffic.gd拥堵穿行、base_escape.gd、simulation_world.gd等；不要覆盖。
- 索引现为battle.neighborhood=simulation.neighborhood，不能仅因注册入口改名断言索引失配。
- 碰撞例外代码按单次move添加并清除；尚无残留实证。
- 对话中提及拥堵计时、多方向包围、基础建筑通行等仅为待验证假设，不能作为根因或修复结论。
- 42项基础回归不覆盖本存档真实基地密集多单位卡点，也不是修复验收。
- 后续应在隔离项目恢复此checkpoint，记录具体单位持续位置、移动/采矿状态、路径点、转向/让行/碰撞/建筑通行状态，再复现截图卡点。矿车has_move_order=false可能在采矿流程，不能判定闲置/不卡；需追踪harvest_state。勿每次重复仅跑通用测试代替实际复现。
