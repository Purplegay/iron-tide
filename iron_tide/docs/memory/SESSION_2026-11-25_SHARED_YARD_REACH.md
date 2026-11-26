# 原版与养成模式的建造场范围

原版模式此前在建造场旁放置电厂只允许两格。按玩家反馈，以养成模式为参照，`scripts/world/build_range_preview.gd` 的 `source_distance` 现在为两种模式的建造场提供至少 12 格（660 世界单位）的地基边缘距离。普通建筑接力扩建仍按目标建筑的 Adjacent 计算。移动建造场的模式条件沿用原规则。

`tests/build_range_regression.gd` 在两个模式下均要求 12 格范围。Godot 4.7.2 无头战场回归共 240 项通过，每种模式逐一检查 2025 个建造场周边格点，并通过实际放置入口在八格以外建成电厂。报告在 `%TEMP%/YardReach-aee56dac/result.json`。本次验证覆盖工程运行时，未进行打包或人工画面验收。
