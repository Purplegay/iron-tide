# 远征面板完全收起

scripts/expedition/runtime.gd 在标题旁加入「完全收起」。点击后隐藏滚动正文和按钮，标题替换为实时主目标摘要首行，终章破盾阶段显示破盾秒数和已控点数。点击进度行恢复收起前的详情显示状态。

扩充 tests/expedition_compact_hud_regression.gd。在隔离用户目录启动真实远征场景，模拟鼠标点击验证收起、目标文字、面板变矮与恢复展开视图。Godot 4.7.2 无头运行 31/31 通过，退出码 0。日志在 %TEMP%/HudOnlyea0a0c7f2136439b855d93a2a392a1b1/result2.log。验证限于测试生成关卡与默认测试窗口尺寸，未逐关做视觉验收。
