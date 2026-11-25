# 指挥官档案可见性

field_guide.gd 的共享档案构建器只为已解锁内容创建控件。无解锁记录的指挥官不显示姓名或头像，未解锁区仅显示剩余条目总数。已知指挥官可展开，再按通信、故事、信物或合击记录单独展开正文。未改解锁逻辑和存档。

Godot 4.7.2 headless，独立临时 APPDATA：expedition_field_guide_regression 41/41，expedition_keepsake_regression 106/106。未人工截图或打包。

## 集齐档案收起

`field_guide.gd` 将解锁数达到总数的指挥官放入共用的「已集齐」按钮下，每次打开默认收起。部分解锁的档案直接列出。只有存在完整档案才创建按钮，剩余条目为零时省去底部统计。

Godot 4.7.2 独立临时 APPDATA 无头运行 `expedition_field_guide_regression`，133/133 通过，覆盖默认隐藏、展开显示、完整档案各 19 节及部分解锁档案。本轮验证范围为场景节点与内容断言。
