# 好莱坞全图预置地基对齐

用户截图：主基地围墙圈住空地，尤里建造场靠一侧，红色清剿标记浮得较远。沿用零售 ALL02UMD SHA `168ed42024991b6c2af4de0e5a667e9c2bf15767741efe99dac975721460b303` 及既有墙栏交接。之前仅四座回收厂按零售地基中心，另外 69 座预置敌方建筑仍经 `Native.find_base_site`（40格吸附与另觅点）；围墙是55格覆层直装。新 `hollywood_mission.gd::retail_site_center/place` 用 `yr_all02umd.site_types` 的零售地基尺寸（含大写 X）、原始角点和旋转变换直接设置全部 73 座敌方预置建筑，记录原始格。主建造场原资料 (75,77)、4×4，换算中心 (128,65)×55。`hollywood_bases.gd::populate` 对补装城市建筑同用该函数，去重从距离阈值改为类型与精确中心。没有挪动188墙栏或四箱原版点。清剿标记使用建筑屋顶的既有投影，间隔 18 屏幕像素，与回收厂一致；血条仍由原实体锚点绘制，未改血条布局。

`tools/export_hollywood_layout_fixture.mjs` 校验原图 SHA，从 375 行 Structures 导出原始可玩区 368 行 `tests/hollywood_retail_layout.json`（另外 7 行原图界外按边界保留，不强装入场）。复跑 `node tools/export_hollywood_layout_fixture.mjs "$env:TEMP/it-hollywood-retail/all02umd.map.map"`。实测 `LAYOUT exact=368 missing=[] duplicates=[]`，墙栏 188 个以类型与格逐项查。用例首跑曾报 10 个中立楼缺失，原因为测试对 `3X3` 未转小写；修复测试解析后并无漏装。资金箱专项调整夹具从合法邻格进入，避开确实会受原围墙物理碰撞的直线；四只箱子均实际拾取且只支付一次。未验从所有方向通路或碰撞近似。

Godot 4.7.2 `--headless --path . res://tests/hollywood_campaign.tscn`，隔离 APPDATA。`.validation/hollywood-full-layout-20261127/`：全图 `-- --all-retail-layout` 12/12 (`final`)，主线 `main` 102/102，`--bridge-tech` 59/59 (`bridge`)，`--stallone-combat` 9/9 (`actor`)，`--cash-crates` 42/42 (`crates2`)，最终上述 stderr 均空，共224项。中间 `crates-final` 并行盟军终关脚本编译错误已不在最终日志。未系统覆盖动态任务生成点、逐像素/截图同机位、旧档地物迁移或发行打包。新开局生效，旧档保持快照位置。未改玩家档；本轮任务触发表未继续减数。
