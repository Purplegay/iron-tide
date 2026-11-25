# 扩展模式建造场范围

扩展模式建造场的最小邻接距离由 8 格调为 12 格（440 → 660 世界单位），按地基边缘计算。`scripts/world/build_range_preview.gd` 的 `source_distance` 同时控制可建预览与实际落点。RA2 模式使用目标建筑自身的 Adjacent 值，已完成且具备 BaseNormal 的建筑可以接力扩建。

`tests/build_range_regression.gd` 调整了边界扫描范围，并要求在原 8 格以外通过正常入口放下电厂。Godot 4.7.2 无头真实战场测试两种模式共 225 项通过，报告在 `%TEMP%/IronTide-Yard12-20261123/result.json`。验证覆盖预览格、实际落点和范围来源归属，未进行画面人工验收或发布打包。
