# 2026-11-27 · 战役 CG 收藏按关卡自动排序

- 用户要求以后默认排序，不在每次加入战役时手动移动分组。排序依据是 `scripts/ui/campaign_cg_catalog.gd::GROUPS` 中各组的阵营与所属 `chapter`，不是媒体文件编号、登记顺序或解锁先后。`groups_for_faction()` 对筛出的新数组按数值关卡号升序排序，`scripts/screens/cg_collection.gd::_make_faction()` 使用它绘制。目录特意保留盟军登记顺序 01、07、02，玩家看到的是 01、02、07；苏军是 01、07。关内影片顺序不变，A08/S08 结局仍归各自第 07 关。未变更任务触发、解锁、奖励、媒体或玩家存档。
- 后续只需登记正确阵营、关卡号及关内顺序，规则已写入 `AGENTS.md` 与战役迁移规范。没有引入另一张手工维护的关卡排序表。
- Godot 4.7.2，无头、隐藏控制台、隔离 `APPDATA`；令 `IRON_TIDE_CG_TEST_PROFILE` 等于隔离的 Godot 用户数据目录。运行 `--headless --path . res://tests/cg_collection.tscn -- --chapter-order`，真实收藏场景 43/43、exit 0、stderr 空，检查两阵营共 5 个关卡分组、19 张卡片的归属及坐标顺序。相同场景无自定义参数首跑 27/27（测试故意模拟写档失败，出现预期警告），独立进程 `-- --cold` 73/73；两次 exit 0。冷读另有百合子页面 `scripts/screens/yuriko_school.gd:207 restore_scroll()` 已离树时访问 `get_tree().process_frame` 的报错，未修复，也未宣称冷读日志洁净。
- 证据在项目父目录 `.validation/cg-chapter-order-20261127-135648/`（order、seed、cold 的 out/err）。未打开有头窗口、未打包或提交。纯收藏排序不新增战役触发；本批核验/补接任务触发器均 0，原有战役进度不变。
