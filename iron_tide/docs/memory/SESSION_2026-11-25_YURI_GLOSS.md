# 尤里遭遇战高光复核

基地车、两栖运输艇、雷鸣潜艇、巡航导弹已通过原版 VPL 烘焙 32 个朝向。图形模式测试核对四种资源均启用 palette_lit，加载 detail_tex，密度为 2。新增或刷新 19 套建筑主体和活动层的 SHP 双倍细节页，共 670 帧、23 页，沿用原画明暗。

Godot 图形模式运行 tests/yuri_skirmish.tscn，101 项通过，其中 23 项专验本批美术。进程退出码 0，日志 .validation/yuri-gloss-test.log。覆盖运行时贴图加载与绘制路径选择，未逐帧目视比对。长期规则见 AGENTS.md。
