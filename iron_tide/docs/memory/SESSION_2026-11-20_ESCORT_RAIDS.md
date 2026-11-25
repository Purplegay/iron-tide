# 2026-11-20 肉鸽护送任务强化

## 需求
用户认为护送任务太简单，要求路线更长，并加入超时空传送过来的额外敌人侵袭。

## 实现
- `scripts/expedition/objectives.gd`
  - 护送终点从原先双方基地连线约 65% 改为敌方方向 90%，仍使用 `ground()` 和同区域可达性检查。
  - 超时空袭击预警圈中心新增醒目的实时秒数（如 `5s`），每次任务 tick 根据 `escort_pending.due - elapsed` 更新；小地图标记同步带 `countdown` 数值与秒数标题。
  - 新护送任务初始化 `escort_next_raid=20.0`、`escort_raids=0`。
  - 每个任务 tick 调用 `escort_raids.gd`；车队暂停不会暂停敌袭调度。
  - 任务摘要显示下一次侵袭倒计时/预警倒计时；预警落点加入战场标记和小地图标记。
- `scripts/expedition/escort_raids.gd` 新增
  - 倒计时达到后在车队附近寻找安全可达落点，提前 5 秒写入可存档的 `escort_pending` 并发出中文预警。
  - 到时生成 3+章节等级的敌军（精英额外+2），生成 `WARPOUT` 超时空视觉效果，立即攻击车队。
  - 每 40 秒重复预警；敌袭单位每 3 秒重定向到当前存活车队，避免车队移动后脱离袭击。
  - 落点距车队至少350，不能落到不可达/危险位置；找不到落点则5秒后重试。
- `scripts/expedition/campaign.gd` 更新护送任务说明。
- `tests/expedition_convoy_cases.gd` 新增长路线、可存档袭击计划、暂停期间预警、敌军实际抵达断言。

## 验证
- 隔离工程 `C:/Users/admin/IronTide/.validation/avoidance-regression-20261120-1220/project`。
- 专项入口 `tests/escort_only.tscn`，独立用户目录与报告目录。
- `ESCORT ONLY checks=50 failed=0`，exit 0。
- 倒计时圈/小地图同步版本专项仍为 `ESCORT ONLY checks=50 failed=0`，exit 0；新增断言确认预警时显示 `5s`。
- 完整 `expedition_regression.tscn` 未作为本次验收：工程已有旧基线失败，并在到达护送用例前因 `expedition_convoy_cases.gd` 的 `run` 接口加载错误中断；日志中其他失败不能归因本次改动。
- 本轮未提交 Git；未操作玩家存档。
