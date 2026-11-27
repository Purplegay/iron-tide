# 《好莱坞梦一场》指挥室文案统一

- 实际改动：`data/waves.json` 的 `yr_hollywood` 与盟军首关、终关共用 `map_title`、`subtitle`、`objectives_text`。`scripts/screens/campaign_command.gd` 不再为好莱坞硬写地点、标题下说明或编号目标；选择该关后两处地点都显示「美国 · 洛杉矶」，目标按接应并展开基地车、摧毁四座回收厂、清除尤里两处基地剩余建筑分三行显示。战场开局 `brief` 原样保留（雷达、资金箱提示）。
- 依据：盟军零售图 `ALL02UMD` 的既有 [触发器索引](HOLLYWOOD_TRIGGER_INDEX.md) 和 [运行复查](SESSION_2026-11-26_HOLLYWOOD_RUNTIME_REVIEW.md)，对照 `scripts/world/hollywood_mission.gd` 的车队提示、四厂目标和后续清剿。仅调整文案入口，本批任务触发器新核验 0、新补接 0，累计与剩余保持既有索引，不重新统计；地图 AI 未动。
- 验证：Godot 4.7.2，以独立 `APPDATA`（目录名含 `CampaignBriefingTest`）运行 `--headless --path . res://tests/campaign_allied_briefings.tscn`。测试实例化真实指挥室，发出三张盟军任务按钮的 `pressed` 信号，逐关核对地图标题、两处地点、三行目标的实际 UI 标签；3/3，退出码 0，Godot stderr 为空。日志 `%TEMP%/CampaignBriefingTest-635b9a5976dd444293c75011b7e7c12e/`。
- 未验证：有头排版、战场出击及流程、发布包。未改任务机制或玩家存档。
