extends RefCounted
## Per-category factory selection. Selecting a tab does not replace battlefield selection.

var hud
var selected: Dictionary = {}
var numbers: Dictionary = {}
var next_number: Dictionary = {}
var buttons: Dictionary = {}
var caption: Label

func _init(owner_hud) -> void:
	hud = owner_hud

func candidates() -> Array:
	var result: Array = []
	if hud.battle == null or hud.prod_tab in ["building", "defense"]:
		return result
	for b in hud.battle.buildings:
		if not is_instance_valid(b) or b.is_dead() or b.side != "ally" or b.is_refinery():
			continue
		for uid in b.buildable:
			if hud._cat_match(GameData.get_unit(str(uid))):
				result.append(b)
				break
	return result

func current():
	var choices := candidates()
	var previous = selected.get(hud.prod_tab)
	if is_instance_valid(previous) and choices.has(previous):
		return previous
	var world_choice = hud.battle.selected_building
	if choices.has(world_choice) and hud._tab_for_building(world_choice) == hud.prod_tab:
		selected[hud.prod_tab] = world_choice
		return world_choice
	# Prefer the category's dedicated factory on first opening.
	for b in choices:
		if hud._tab_for_building(b) == hud.prod_tab and not b.under_construction and b._buildup_play < 0.0:
			selected[hud.prod_tab] = b
			return b
	for b in choices:
		if not b.under_construction and b._buildup_play < 0.0:
			selected[hud.prod_tab] = b
			return b
	selected[hud.prod_tab] = choices[0] if not choices.is_empty() else null
	return selected[hud.prod_tab]

func remember(b, category: String) -> void:
	selected[category] = b

func choose(b) -> void:
	if not candidates().has(b):
		return
	selected[hud.prod_tab] = b
	hud._unlock_focus = ""
	hud._refresh_production()

func number_for(b) -> int:
	var key := "%s:%d" % [hud.prod_tab, b.get_instance_id()]
	if not numbers.has(key):
		next_number[hud.prod_tab] = int(next_number.get(hud.prod_tab, 0)) + 1
		numbers[key] = next_number[hud.prod_tab]
	return int(numbers[key])

func signature() -> String:
	var parts := PackedStringArray()
	for b in candidates():
		parts.append("%d:%s" % [b.get_instance_id(), b.under_construction])
	return ",".join(parts)

func build(host: Control) -> void:
	buttons.clear()
	caption = null
	var choices := candidates()
	if choices.is_empty():
		return
	caption = hud.kit.make_label("", 12, hud.kit.COL_DIM)
	host.add_child(caption)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	host.add_child(grid)
	for b in choices:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 1)
		grid.add_child(box)
		var btn: Button = hud.kit.ra_button(11, 40)
		btn.set_script(hud.ProductionTooltipScript)
		if is_instance_valid(hud._production_inspector):
			hud._production_inspector.bind(btn, b.display_name)
		btn.custom_minimum_size = Vector2(76, 40)
		btn.toggle_mode = true
		btn.clip_text = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func(): choose(b))
		box.add_child(btn)
		var bar: ProgressBar = hud.kit.ra_progress(preload("res://scripts/ui/production_clock.gd").color_for(str(b.faction)))
		bar.max_value = 1.0
		bar.step = 0.0
		bar.custom_minimum_size = Vector2(0, 4)
		box.add_child(bar)
		buttons[b.get_instance_id()] = {"button": btn, "bar": bar}
		number_for(b)
	update()

func update() -> void:
	var active = current()
	if is_instance_valid(caption) and is_instance_valid(active):
		caption.text = "独立生产 · 当前工厂 %d" % number_for(active)
	for b in candidates():
		var entry: Dictionary = buttons.get(b.get_instance_id(), {})
		if entry.is_empty() or not is_instance_valid(entry.button):
			continue
		var status := "空闲"
		var fraction := 0.0
		var detail: String = b.display_name
		if b.under_construction or b._buildup_play >= 0.0:
			status = "施工中"
			fraction = clampf(b.build_elapsed / maxf(0.01, b.build_total), 0.0, 1.0)
		elif not hud._queue_uid(b).is_empty():
			fraction = b.queue_progress(hud._queue_uid(b))
			status = "%d%% · %d项" % [int(fraction * 100), hud._queue_count(b)]
			var job: Dictionary = GameData.get_unit(hud._queue_uid(b))
			var state: String = hud._production_status("生产中", float(job.get("cost", 0)), b)
			if state != "生产中": status = state.left(7) + ("…" if state.length() > 7 else "")
			detail += "\n" + hud._queue_caption(b)
		var short_name: String = {"GAPILE": "兵营", "GAWEAP": "战车厂", "GAAIRC": "机场", "GAYARD": "船坞", "NAYARD": "船坞"}.get(b.building_id, b.display_name)
		entry.button.text = "%s %d\n%s" % [short_name, number_for(b), status]
		entry.button.button_pressed = b == active
		entry.button.tooltip_text = detail + "\n点击：切换此工厂的生产目录与队列"
		entry.bar.value = fraction
