# IronTide 英雄契约统一约定（用户明确要求记忆，2026-11-12）

- 项目：C:\Users\admin\IronTide。炉火、守望者、北辰、铁脊的契约 UI 要统一维护：契约徽章、W / 被动奖励图标、等级、技能演示、升级和快速装配入口不能只给炉火提供。图标保持究极传说金色系列，英雄及技能使用可区分的中心符号；技能卡池与英雄养成共用组件及图标来源。
- 快速装配直接进入对应英雄独立的 W / 被动槽；未获得奖励不可装配，已装配显示状态。保留普通兵种装配、技能等级和资源，沿用真实保存与失败回滚入口，新增对局生效。
- 已确认抽取规则：未获得契约共用每抽 0.35%，命中后等概率选择；契约不重复获得，全部获得后退出池子。目录、数量和英雄入口动态读取配置。
- 对应源码：iron_tide/data/skills.json 的 hero_contracts；scripts/ui/{progression_icon,hero_contract_reward,furnace_contract_panel,expansion_contract_panel}.gd；装配权威 scripts/rules/hero_loadouts.gd。
- 用户要求尽量少截图；优先源码、布局与隔离 headless 验证。图标最终观感由用户在游戏中确认，不能用 headless 通过代替。
- 本轮已实现并经 furnace_contract_regression 隔离 headless 596 项检查通过（包含 12 个可区分徽章、8 张卡的装配限制/持久化、两处入口及滚动范围）。证据：C:\Users\admin\IronTide\.validation\hero-contract-ui-final-20261112\reports。未截图，未操作玩家真实存档；最终观感仍待用户确认。
