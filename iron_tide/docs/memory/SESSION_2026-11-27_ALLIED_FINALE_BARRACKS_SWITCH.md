# 盟军终关：双阵营兵营切换（2026-11-27）

用户截图显示步兵页只列苏军兵营。复查 `ALL07SMD_SCRIPT_RECHECK.tsv`（火地岛 `NACNST` 与 `0964b13c` 盟军基地车事件）及 `SESSION_2026-11-27_ALLIED_FINALE_BASE_TABS.md`：建造场决定建筑／防御目录；旧工厂筛选误将这项限制施加给步兵栏。此处是操作界面修复，不变更原图脚本、地图 AI、国家规则或科技前置。

- `scripts/ui/hud.gd` 与 `scripts/ui/production_factories.gd`：终关步兵栏并列列出实际拥有的兵营，点击兵营按钮或在战场选中兵营，展示所选兵营的步兵与独立队列，下单不跨到另一座；两方都有建造场时，基地页签仍可快捷选中该方兵营。无对应建造场时，尚存的兵营仍可切换与生产；当前兵营被毁，回落到剩余兵营。建筑、防御的建造场限制不放宽。
- 验证：Godot 4.7.2 隐藏无头、独立 APPDATA，`res://tests/allied_finale_playable.tscn` 从真实战役菜单出击，83/83；独立进程 `-- --cold` 5/5、`-- --cold-dual` 4/4、`-- --cold-barracks` 3/3，全部退出 0、stderr 空。证据 `.validation/finale-barracks-switch/{main,cold,cold-dual,cold-barracks}.{out,err}`。
- 测试以夹具放置两座兵营，移除盟军建造场后用实际 HUD 按下信号为两边分别排 E2/E1，确认队列独立，跳过夹具展开动画、手动推进实际生产，共扣 300 并出 2 个兵。另测战场建筑选择信号、失兵营回落、真实单建造场双兵营存读档。未做有头画面验收、未检验截图中的国家限制是否符合原关所有覆盖，未改玩家存档或重新打包。
