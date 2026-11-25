class_name PowerBarControl
extends Control
## 电力负载表。红格为耗电，黄格为最多 100 点余量，绿格为其余供电。

const GREEN := Color("50ce66")
const YELLOW := Color("ffce38")
const RED := Color("ef4535")

var vertical := false
var produced: float = 0.0
var drain: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_power(p: float, d: float) -> void:
	produced = maxf(0.0, p)
	drain = maxf(0.0, d)
	queue_redraw()

func is_low_power() -> bool:
	return produced < drain - 0.001

func _process(_delta: float) -> void:
	if is_low_power():
		queue_redraw()

func _draw() -> void:
	var length := size.y if vertical else size.x
	var width := size.x if vertical else size.y
	if length <= 2.0 or width <= 2.0:
		return
	if vertical:
		draw_set_transform(Vector2(0, size.y), -PI * 0.5, Vector2.ONE)
	draw_rect(Rect2(0, 0, length, width), Color("111821"))
	# SidebarPower.ts 的电量高度曲线，大电网占用更多格子。
	var peak := maxf(produced, drain)
	var span := length - 2.0
	var used_end := 0.0
	if peak > 0.0:
		var level := maxf(100.0, peak) / 100.0
		var log_level := log((level + 5.0) / 5e7) / log(10.0)
		var total := span * clampf(1.0 + log_level / (2.0 * (level + 3.0)), 0.0, 1.0)
		used_end = roundf(total * drain / peak)
		var reserve := clampf(produced - drain, 0.0, 100.0)
		var yellow_end := roundf(total * (drain + reserve) / peak)
		var start := 0.0
		for band in [[used_end, RED], [yellow_end, YELLOW], [roundf(total), GREEN]]:
			var end: float = band[0]
			if end > start:
				draw_rect(Rect2(1 + start, 1, end - start, width - 2), band[1])
			start = end
	for tick in range(4, int(span), 4):
		draw_rect(Rect2(1 + tick, 1, 1, width - 2), Color(0, 0, 0, 0.45))
	# 白线始终标在耗电处，零耗电时贴底。
	draw_rect(Rect2(minf(1 + used_end, length - 2), 1, 1, width - 2), Color.WHITE)
	var border := Color("4c798e")
	if is_low_power():
		border = RED.lerp(Color("ffaca0"), 0.5 + 0.5 * sin(Time.get_ticks_msec() * TAU / 900.0))
	draw_rect(Rect2(0.5, 0.5, length - 1, width - 1), border, false, 1.0)
