# 肉鸽定时增援交接 · 2026-11-19

用户要求每次任务进展/完成及时写持久记忆与项目交接，防止换窗口忘记。跨窗口恢复请先阅读此文及 docs/EXPEDITION_REINFORCEMENTS.md。

## 已完成
- scripts/expedition/reinforcement_plan.gd：时间改为价格 / 100 / 2 分钟，删除各兵种首个单位0秒提前出场；英雄从 frozen.hero_training 取攻防较高训练等级，每级额外30秒，不再误用hero_builds累计建造次数。兼容旧英雄名单字段。
- scripts/expedition/runtime.gd：按序部署到期单位，只有成功才移除；失败保留并继续其他条目，避免同批丢兵。加WARPOUT到场环、提示和HUD下一批倒计时。
- 跨关幸存者开局保留；旧战斗存档队列不重算，下一场完整采用新规则。
- tests/expedition_reinforcement_regression.gd/.tscn：15/15无头真实战场回归，两次运行通过；隔离用户目录，不操作玩家正式存档。
- 规则说明 docs/EXPEDITION_REINFORCEMENTS.md。

## 未验证/边界
- 尚未人工查看特效或完整一局节奏；恢复队列测试仅复制队列，并非完整磁盘冷读档。
- 未打包、提交、推送；工作区已有大量其他未提交修改，不要覆盖或回退。
- 测试输出 C:/Users/admin/AppData/Local/Temp/IronTideReinforcement-ee012b7ba1774fc78a5922bc27d7262e/result.json。

## 下一步
等待用户反馈节奏或后续要求；不自行更改英雄30秒/级系数。
