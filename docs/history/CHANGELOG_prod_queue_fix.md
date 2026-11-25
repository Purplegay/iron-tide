# CHANGELOG —— 同单位无法连续建造 修复

需求：「同单位居然不能连续建造吗？」

## 症状
选中建筑后点击某个单位按钮，能造出第一个；**再点同一个按钮却经常没反应**，无法连续排队。生产/施工期间尤其明显。

## 根因（真凶是 UI 重建，不是后端）
后端完全支持重复入队——`building.enqueue(uid)` 只是 `production.append(uid)`，没有去重或队列上限。问题出在 HUD：

1. `hud.gd::_process()` 在 `_busy`（施工中或队列非空）时把刷新间隔压到 **0.08s**，每 tick 调用 `_refresh_production()`：
   ```gdscript
   if _proc_tick >= _thr:      # _thr = 0.08 (busy) / 0.45 (idle)
       _proc_tick = 0.0
       _refresh_top()
       if is_instance_valid(battle.selected_building):
           _refresh_production()
   ```
2. 而 `_refresh_production()` 开头就是 `_clear_nodes(prod_box)` —— **整体销毁并重建所有生产按钮**。

Godot 的 `Button.pressed` 在**鼠标抬起**时才触发。人类一次点击的「按下→抬起」通常横跨 2~8 帧。生产一开始 `_busy=true`，重建频率 12.5 次/秒，几乎每次点击的按下与抬起之间都会撞上一次重建 → 按下的那个按钮实例已被销毁/替换 → `pressed` 永远不触发 → **点击被吞掉**。于是表现为「只能造一个」。

## 修复：给生产面板加「签名守卫 + 原地刷新」
`_refresh_production()` 不再无脑重建，改为：

```gdscript
var sig := _prod_signature(b)                 # 建筑 id|页签|施工态|可造列表|队列构成
if sig == _prod_sig and prod_box.get_child_count() > 0:
    _update_production_live()                 # 结构没变 → 只原地刷新，绝不销毁按钮
    return
_prod_sig = sig                               # 结构变了 → 整体重建
_prod_buttons.clear(); _prod_bars.clear(); _clear_nodes(prod_box)
```

- `_prod_signature(b)`：`"<instance_id>|<prod_tab>|<under_construction>|可造uid列表|队列uid列表"`。只有这些**构成性**因素变化才重建；`资金变化`（`funds_changed` 只影响按钮可用性）、`进度推进` 都不改变签名。
- `_update_production_live()`：原地更新每个按钮的 `disabled`（按当前资金）+ 施工/生产进度条的 `value` 与文案。
- 新增缓存 `_prod_buttons`(uid→Button) / `_prod_bars`("build"/"queue"→[ProgressBar, Label]) / `_prod_sig`。
- `_make_build_bar(...)` 增加 `kind` 形参，把进度条与其说明文字登记进 `_prod_bars` 便于原地刷新。

## 顺带修：选中建筑后面板迟滞
`battle.select_building()` **不发** `Events.selection_changed`（只有选单位发），所以生产面板此前只能等 `_process` 的 0.45s 轮询才更新，选中建筑后有明显迟滞。
→ 在 `_show_building_info()` 末尾直接补一句 `_refresh_production()`，选中即有。

## 校验
- 冒烟：**`SMOKE_SUMMARY ok=202 fail=0`**（上轮 200，本轮 +2）
  - `prod_panel_inplace_no_rebuild`：连续两次 `_refresh_production()`，生产按钮 **instance_id 保持不变** → 证明不再重建（点击不会丢）。
  - `prod_repeat_enqueue_two`：同一 uid 连续 `enqueue` 两次，`production.size() == 2` → 证明后端支持同单位连续建造。
- 实拍新增 **`iso_prod.png`**：选中「指挥中心」→ 右下生产队列即时显示「MRV 采集车 / 300」，无迟滞、无报错。
- 其余 HUD（`iso_selbar.png` / `iso_unit.png`）无回归。

## 备注
`_process` 的周期调用**保留为 `_refresh_production()`**（不改成轻量版）——因为它同时承担「结构变化兜底重建」的职责；签名守卫保证它在结构未变时是零销毁的原地刷新。
