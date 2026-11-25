# 验证与交接

## 现有入口

- iron_tide/tests/run-navigation-building.ps1 -Suite <已有场景名> -RunRoot <新的独立目录>。复用前读取当前支持的suite和参数。
- tools/performance_soak.py：性能采样；tools/native_function_profile.py：函数诊断；参数和证据边界查当前工具及[性能记录](../../../tools/PERFORMANCE.md)。
- 测试源在iron_tide/tests；本机运行证据在.validation。路径或哈希不等于跨机已交付。

## 既有约定

1. 使用隔离工程／玩家目录，不覆盖原存档、不停止用户游戏，不并行跑性能测试或大批复制污染对照。
2. GPU／像素检查需真实图形和未激活私有桌面；最小化／移出屏幕不是等价隔离，headless不能证明画面。
3. 固定源和夹具，核对引擎、save/meta、CPU、模拟推进及源码漂移。
4. 区分实现、脚手和既有基线失败，保留失败证据，不降断言凑通过。
5. 正确性、性能、用户体验、包版本分别说明；重复复测的断言数不等于独立功能数。
6. 打包夹具和性能快存用途不同，换错存档不能靠降低规模断言解决。
7. 明确要求包再制作；提交推送按当次授权执行。

来源：[历史性能交接与失败候选](sources/memories/extensions/ad_hoc/notes/2026-11-16-irontide-performance-handoff.md)；[夜枭／猎蛛制作避坑](sources/memories_v2/extensions/ad_hoc/notes/2026-11-17-irontide-night-hunter-skin-lessons.md)；[远征与HUD完整记忆](sources/memories_v2/extensions/ad_hoc/notes/2026-11-17-irontide-expedition-and-hud.md)。

## 本次整理验证

本轮没有启动游戏或重跑历史测试。核对记忆归档原字节、摘录行号、主题链接以及关键源码／已有超武报告。超武580项是本聊天上一轮实际运行结果，小型原始汇总已复制到[evidence](evidence/ai-storm-damage-20261119-summary.json)；完整日志和隔离工程保留在原.validation。
