# CHANGELOG —— 红警3 风格血条重制

需求：「血条 ui 有点丑，可以参考红警3」。

## 结论：从「1 个纯色矩形」升级为 RA3 造型的完整血条

旧血条极其简陋（世界血条）：
```gdscript
draw_rect(Rect2(-bw2*0.5-1, by2-1, bw2+2, 6), Color(0,0,0,0.6))   # 黑底
draw_rect(Rect2(-bw2*0.5,   by2,   bw2*pct, 4), bc)                # 纯色填充
draw_rect(Rect2(-bw2*0.5,   by2,   bw2,   4), Color(1,1,1,0.12), false, 1)  # 淡白描边
```
面板血条是 Godot 原生 `ProgressBar` + 两个 `StyleBoxFlat`，与场上血条**风格完全不一致**。

## 新方案：新增 `HpBar` 工具 + `HpBarControl` 控件，三处共用一套视觉语言

### `scripts/ui/hp_bar.gd`（新，`class_name HpBar extends RefCounted`）
只做静态绘制，不持状态；世界血条与面板血条共用。

造型要素（对齐 RA3 单位血条）：
| 层 | 内容 |
|---|---|
| ① 外框 | 1px 深色硬描边（`FRAME = 0.012/0.018/0.028/0.95`），比底槽大一圈 |
| ② 底槽 | 深蓝黑半透明 `TRACK = 0.055/0.068/0.088/0.82` |
| ③ 内衬 | 上暗 `TRACK_TOP` + 下亮 `TRACK_BOT`，制造内凹槽感 |
| ④ 填充 | 内缩 1px；顶部 34% 高光条（`lightened(0.30)`）+ 底部 24% 阴影（仅条高 ≥5 时）→ 斜面金属感 |
| ⑤ 分段刻线 | 整条等分，中线深色 `NOTCH = 黑 0.34` —— RA3 的「分格」读数 |
| ⑥ 低血脉冲 | `frac < CRIT(0.18)` 时填充 alpha 按 `0.60+0.40*sin(t*0.012)` 抖动，预警 |

配色 API：
- `tier_color(frac)` —— 面板用，绿/黄/红三分（`<0.33` 红、`<0.66` 黄、否则绿）。
- `faction_color(side)` —— 盟军绿 `0.36/0.86/0.42` / 敌军红 `0.95/0.38/0.32`。
- `world_fill(side, frac)` —— **世界血条**：满血用阵营色；`frac<0.5` 起向告警红 `TIER_LOW` 过渡 `k*0.8`（低血=危险，保留敌我辨识）。
- `seg_count(width)` = `clamp(round(width/9), 2, 16)`，小血条自动少刻线。

### `scripts/ui/hp_bar_control.gd`（新，`class_name HpBarControl extends Control`）
替换 `ProgressBar`；`_draw()` 内直接调 `HpBar.draw_bar`，与场上血条**像素级一致**。
- `set_hp(cur, mx)`：值变化才 `queue_redraw`；低血时持续重绘以驱动脉冲。
- `mouse_filter = IGNORE`，不抢交互。

### 接入点（三处）
| 文件 | 改动 |
|---|---|
| `scripts/units/unit.gd` | `_draw()` 世界血条 → `HpBar.draw_bar(self, Rect2(-w*0.5, y, w, 5), pct, HpBar.world_fill(side, pct))`；宽度 `max(22, r*2.2)`、y 由 `-r*3.0 → -r*2.7`（贴更近）、空中 `-3.9 → -3.7` |
| `scripts/buildings/building.gd` | 血条宽度 `max(44 → 50, r*2.4)`、高度 `5 → 6`，改用 `HpBar` |
| `scripts/ui/unit_icon.gd` | 选中条图标底部血条 → `HpBar.draw_bar(..., HpBar.tier_color(hp_frac))`（与面板同色阶） |
| `scripts/ui/hud.gd` | `sel_hp_bar` 由 `ProgressBar` → `HpBarControl`；`_make_hp_bar` 重写；删除 `_hp_style`；`_refresh_selection_live` 两处改为 `sel_hp_bar.set_hp(...)` |

## 校验
- 导入：无 `Parse Error / SCRIPT ERROR`；两个新类注册为全局类。
- 冒烟：**`SMOKE_SUMMARY ok=200 fail=0`**（上轮 190，本轮 +10：`HpBar` 配色三分档、阵营色、满血=阵营色、低血偏移红、分段钳制、控件类型与存值）。
- 实拍（新增 `iso_hpbar.png` 血条对照特写，把 5 个盟军单位血量设为 100/75/50/25/10%）：
  - 世界血条：凹槽黑框 + 绿色填充 + 顶部高光 + 竖向分段，受损后转橙红，低血脉冲；
  - 面板血条（选中铁锤坦克）：分段绿条与右侧数值分离；
  - 选中条图标：底部分段血条绿/黄/红三档可见。
- `iso_unit.png / iso_selbar.png` 其余 HUD 无回归。

## 设计取舍（备忘）
- 世界血条**保留阵营色底**（盟绿/敌红）以保证敌我辨识，血量下降时向红警式告警红过渡；面板血条（阵营已由文字标注）直接用 RA3 绿/黄/红三分档。
- 分段刻线刻意只在**填充段**清晰可见（空槽为深色，刻线自然隐去），避免满屏花格。
