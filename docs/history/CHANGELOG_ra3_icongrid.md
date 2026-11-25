# 变更说明：HUD 去「手游感」·红警3 式图标化（第一批）

用户口径：**「UI 往 RA3 靠近，现在太手游了，用 RA2 素材也行。」** 本轮先把最像手游的三处
「文字按钮墙 / 文字按钮矩阵」改成红警3 式**图标块**，并收起左上大段说明文字。

## 1. 指令栏：文字按钮 → 方形图标块（hud.gd / ui_kit.gd）

- `ui_kit.gd` 新增 `ra_icon_tile(size)`：方形命令/技能图标块（无文字，`normal/hover/pressed/disabled/focus`
  全套 RA3 StyleBox；后续由 `Ra3Skin` 自动升级为带高光的 RA3 贴图块）。
- `hud.gd` 新增内部类 `CmdGlyph extends Control`（矢量自绘，`ra3_skip`）：
  18 个命令图标 + 7 个技能图标，全部用 `draw_line / draw_arc / draw_colored_polygon` 画，
  零美术资源依赖。
- `_add_cmd` 改为 31px 图标块 + 右下角热键角标（名称/说明进 tooltip）；
  `_add_command_grid` 列数 3 → **9**（18 个命令 = 2 行全部可见，不再被面板裁切）。
- 新增 `_cmd_hotkey(id)`（A/S/G/X/Y/T/P/C/H/F/M/N/K/L/D）与 `_ability_glyph(name)`（按技能名关键字选图标）。

## 2. 技能栏：文字标签 → 图标块 + 冷却覆盖层（hud.gd）

- `_rebuild_ability_bar`：每个技能改为 38px 图标块 + 左上热键角标（Q/W…）+ 冷却数字覆盖层，
  右侧跟随技能名；tooltip 保留 描述 / 冷却。
- `_update_ability_live`：不再改 `btn.text`，改为设置冷却覆盖层文字 + `modulate` 置灰。

## 3. 左上说明文字：默认收起（hud.gd）

- 原来 8 行的「操作 / 红警2热键 / 通用 / 教学 / 准备时间 …」文字墙默认不再盖住地图。
- `_build_log`：`log_box` 包一层 `log_panel`（RA3 面板），默认 `visible = false`；
  上方常驻一个小按钮「情报 [展开]」，点击在展开/收起间切换（新增 `_toggle_log()`）。

## 校验

- `--headless --editor --quit` 导入：无 Parse / SCRIPT ERROR。
- 冒烟：`SMOKE_SUMMARY ok=303 fail=0`（与基线一致，`cmd_buttons` 键、`button_pressed`、
  `_ability_btns` 数量等断言全部保留）。
- 实拍：`iso_ui.png`（指令栏图标化 + 左上收起）、`iso_selbox.png`（选中面板 9×2 指令图标）。

## 待续（下一批候选）

- 顶部资源/控制条图标化（资金/击杀/视角/暂停/倍速/GM/返回 → 图标）。
- 选中单位头像改用 RA2 cameo 原图（当前为程序化剪影）。
- 小地图外框 RA3 化；「未选中单位」空面板收口。
