# SESSION 2026-11-20 战后事件强化标题

## 问题
战后事件“训练教官”中的训练选项标题固定显示“强化主力 · 20 补给，攻防各 +1 级”，玩家无法知道本次强化针对哪个兵种。事件数据本身已有 `item.id`，只是标题没有使用它。

## 修复
- `scripts/expedition/market.gd`：构造训练事件选项时使用 `Army.training_name(id)`，标题改为“强化<具体兵种> · 20 补给，攻防各 +1 级”。
- `tests/expedition_offer_capacity_cases.gd`：对所有生成的训练事件选项断言标题包含对应兵种名称。

## 验证
- Godot 4.7.2 编辑器扫描完成，无新增脚本编译错误。
- 直接执行 case 脚本无效，因为测试 case 依赖场景提供的 `Expedition` 自动加载。
- `tests/expedition_regression.tscn` 启动未进入测试：该回归场景要求 `IRON_TIDE_REPORT_DIR` 指向包含 `CodexIronTideValidation` 的临时报告目录，当前命令未设置，因此按测试保护逻辑退出 2。
- 未修改工作区中本轮之前已有的 `market.gd` 其他变更。
