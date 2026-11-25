class_name HpBarControl
extends Control
## 红警3 风格血条控件：替换 ProgressBar，改由 HpBar 统一绘制，
## 与场上的世界血条保持完全一致的造型（凹槽 + 描边 + 分段 + 高光）。
## 本轮新增：掉血残影 + 受击白闪，让面板血条与世界血条同步「有打击感」。

var _cur: float = 1.0
var _mx: float = 1.0
var _use_tier: bool = true   # true=按血量绿/黄/红；false=按阵营色
var _ghost: float = 1.0      # 掉血残影比例（落后于 _cur）
var _flash: float = 0.0      # 受击白闪剩余（1→0）

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

## 更新血量（每帧可安全调用）。
func set_hp(cur: float, mx: float) -> void:
	var nmx: float = maxf(1.0, mx)
	var prev_frac: float = clampf(_cur / maxf(1.0, _mx), 0.0, 1.0)
	if absf(cur - _cur) > 0.001 or absf(nmx - _mx) > 0.001:
		if cur < _cur - 0.001:
			_flash = 1.0                        # 掉血瞬间触发白闪
			_ghost = maxf(_ghost, prev_frac)    # 残影保留旧血量
		_cur = cur
		_mx = nmx
		queue_redraw()
	elif _cur / nmx < HpBar.CRIT:
		queue_redraw()   # 低血脉冲需要持续重绘

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var frac: float = clampf(_cur / maxf(1.0, _mx), 0.0, 1.0)
	var need: bool = false
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 5.0)
		need = true
	if _ghost > frac:
		_ghost = maxf(frac, _ghost - delta * 1.4)
		need = true
	elif _ghost < frac:
		_ghost = frac
	if frac < HpBar.CRIT:
		need = true
	if need:
		queue_redraw()

func set_use_tier(enabled: bool) -> void:
	if _use_tier != enabled:
		_use_tier = enabled
		queue_redraw()

func _draw() -> void:
	if size.x < 3.0 or size.y < 3.0:
		return
	var frac: float = clampf(_cur / maxf(1.0, _mx), 0.0, 1.0)
	var col: Color = HpBar.tier_color(frac) if _use_tier else HpBar.faction_color("ally")
	HpBar.draw_bar(self, Rect2(Vector2.ONE, size - Vector2(2.0, 2.0)), frac, col, 0, _ghost, _flash)
