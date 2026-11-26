# 存档 1 P95 三处热点候选（2026-11-26）

依据 `.validation/p95-hotspots-20261126/report.md`：deep-1 慢帧中爆炸进入单位 receive_hit 34.459 ms、候选搜集 0.717 ms；AI 派单 5.982 ms、深度排序 0.934 ms；focus-2 页读取/尺寸检查累计 121.098 ms，逐出插入仅 1.356 ms。不同插桩采样不能与正式 P95 相加，也不能当作优化收益。本批不调整派单预算、爆炸候选、深度排序、模拟时钟或视觉精度。

本批新增（未提交；相关文件有其他并行修改）：
- `scripts/units/unit.gd`：receive_hit 中仅在正伤害且 MGTK 持有 mirage_guard 时调用 Ground.defend；Armor.defend 仅对正伤害 APOC 调用。两者原函数入口在其余情况下直接返回输入；防御、护盾及死亡链的顺序不变。没有裁剪其他扩展回调。focus-2 的 `_die` 包含同步击杀、载员、事件、残骸和动画，未擅自延后。
- `scripts/world/house_ai.gd`：单次 train_army 内按 uid 复用 AI 产品许可、生产目录、静态 combat_product 判定和单位数据；每条产线仍实时检查价格、can_queue、人口/队列与评分，成功下单仍更新资金和数量。原有 opponents/matchups 同轮复用不变。
- `scripts/buildings/building_art_warmup.gd`、`scripts/screens/battle_screen.gd`：setup/restore 后将现存建筑（含已建成）的当前身体页与活动/待机动画放入现有异步队列，再排已经实例化的 SHP 单位站立页。后者原先排该兵种全部细节页，可能挤出热页；现缩减到当前入口页，兼容无 Guard 序列的兵种。正在加载、已缓存及已经排队的页不会重复加入。没有在首次生产订单同步调用 RA2Art.art(uid)，生产预取未实现。原有 theater_sheet_id 路径修改来自并行工作，不属于本批。
- `scripts/core/shp_detail.gd` 的 LRU 候选已撤回、恢复原逻辑：报告显示逐出/插入只占 1.356 ms，且 Canvas 自身持有纹理引用，不能证明共享字典命中时删插有净收益。64 MiB 预算、纹理像素和 ResourceLoader 缓存行为保持不变。
- `tests/p95_three_hotspots_regression.gd/.tscn`：真实 Godot 项目内验证同轮共享产品事实与独立计算在两种数量/三种预算下选兵一致、队列资格实时复核、单位当前页排队及重复预热去重。9 项检查通过；不读取玩家存档。

验证：Godot 4.7.2 `--headless --editor --quit` exit 0、stderr 空；新增专项场景 `--headless --path <project> res://tests/p95_three_hotspots_regression.tscn` exit 0、stderr 空、9 项无失败；相关脚本 `git diff --check` 无空白错误。主工程通用测试要求隔离的自定义用户目录，直接运行提前退出 2。隔离副本中的多个 `.godot/imported/*.ctex` 缺失（主工程共享导入缓存同期也缺相应页），场景测试出现资源错误与失败，该结果无效；副本编辑器扫描超时。独立 SceneTree 脚本曾因 autoload 编译错误作废。未做可信的完整命中链/AI 对局/贴图实际画面回归、逐页 miss/逐出统计、驻留内存或私有图形 Release 两场无插桩 P95/P99。候选未达到报告规定的保留门槛，不能宣称性能收益。

下一步在资源导入稳定、无其他 Godot 进程时，以隔离自定义用户目录运行受击路径、AI 生产和贴图回归；记录新旧页 miss、预热耗时与工作集内存。然后用报告中的存档 1、3x、30 秒、1600x900、正式 Release 口径进行同期至少两场 A/B 对照；只有行为对账且最好值与均值均改善才保留。不撤回其他人的并行修改。
