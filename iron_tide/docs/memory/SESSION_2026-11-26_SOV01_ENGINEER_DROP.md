# 苏军第一关工程师空投时序

## 根因

《时空转移》原图事件索引 `SOV01_TRIGGER_INDEX.md` 明确包含 `Reinforce_10 Engineers` 与 `Reinforce_6 Engineers`。此前 `scripts/world/time_shift.gd` 在进入夺电阶段或工程师全部损失后直接调用 `spawn_unit("SENGINEER", ...)`，所以字幕“我们正在空投工程师支援”之后工程师瞬间出现在地面，没有飞机、伞降或落地等待。

## 实际改动

- `scripts/world/american_paradrop.gd`
  - 抽出共享 `_start_drop()`，支持不依赖超级武器建筑的剧情空投。
  - 新增 `launch_story(world, point, infantry, count)`，复用运输机飞入、逐个投放、降落伞、落地碰撞恢复和自动清理逻辑。
  - 空投人数和兵种从运输机状态读取，避免剧情批次被固定成美国大兵 8 人。
  - 下降速度调整为约 8.3 秒可见下降时长；此前约 4.2 秒，用户反馈过快。
- `scripts/world/time_shift.gd`
  - 阶段 1 清除时光机防御后，将原先瞬间生成的 10 名苏军工程师改为 `launch_story(..., "SENGINEER", 10)`。
  - 阶段 2 工程师全部损失后的 6 人补充改为 `launch_story(..., "SENGINEER", 6)`。

## 验证

- Godot 4.7.2：`--headless --path . --editor --quit` 通过，无脚本解析错误。
- 已通过代码核对确认空投单位在 `para_height` 存在期间进入空中单位组、关闭碰撞并绘制降落伞，落地后恢复地面组和碰撞。
- 尚未完成隔离图形窗口中从苏军第一关实际推进至字幕和空投的截图回归；此前该场景 runner 曾超过 120 秒未完成，不能宣称已做完整实机演出验收。
