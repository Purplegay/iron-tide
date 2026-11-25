# 油罐车接应点

普通支线默认靠近两军之间。油罐车现在从己方部署点侧翼开始搜可达地点，实际车位限在部署点 1200 世界单位内，选点和生成后都检查现有敌方单位视野、射程和敌方建筑安全距离。找不到合适位置时沿用普通支线回退。改动位于 scripts/expedition/field_missions.gd。

Godot 4.7.2 隔离战场专项 59 项通过，覆盖出生距离与威胁检查、护送、恢复存档、拆车和损失。报告在 `%TEMP%/CodexIronTideValidation-tanker-32fb958a79ad45e78d833d16568593d4/field-missions.json`。验证使用测试场景，截图中的第 17 关战况未复现。
