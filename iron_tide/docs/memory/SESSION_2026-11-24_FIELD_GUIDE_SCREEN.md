# 支线百科独立页面

新增 scenes/field_guide.tscn，scripts/expedition/field_guide.gd 使用全屏 Control。主菜单和远征营地打开时隐藏来源，返回按钮或 Esc 恢复原界面及先前焦点。页头使用战区地图，20 项任务通过左侧目录切换，正文按出现条件、行动和结果分段。指挥官口述档案继续依据玩家记录展示。

更新 tests/expedition_field_guide_regression.gd 的页面查找及关闭断言。在隔离 APPDATA 下用 Godot 4.7.2 运行该场景，133 项通过，涵盖两个入口、任务正文、许可目录、档案与主菜单返回。另已渲染并检查 2560×1440 默认任务页。