# 英雄增援到场时间修正（2026-11-20）

用户指出路线预览中守望者显示 26:00 英雄训练加时不合理，要求英雄遵循原有单位计时。已统一英雄与普通单位：到场基础时间仅 `cost × 0.3 秒`，火力/生命训练等级不再作为等待加时；跨局超时空减时与军团伤亡规则保持不变。英雄到场预览不再显示“英雄训练”项，只显示基础时间与超时空减时。

生产/界面改动：`scripts/expedition/reinforcement_plan.gd` 移除 hero level delay；`scripts/expedition/insights.gd` 删除训练加时明细。回归更新：`tests/expedition_reinforcement_regression.gd` 覆盖高训练英雄与普通同种单位同计时；`tests/expedition_insights_regression.gd` 覆盖训练英雄预览仍遵从计时规划且无英雄专属加时行。`docs/EXPEDITION_REINFORCEMENTS.md` 已同步新规则。

隔离 Godot 4.7.2 headless 验证通过：`expedition_reinforcement_regression` 23/23、`expedition_insights_regression` 41/41，进程 exit 0、无脚本错误。证据目录：`%TEMP%/iron-tide-hero-arrival-bca8d988a97a4c03a3cfd58f9c989795/reports/`；未修改存档、未运行整局人工视觉测试、未提交。
