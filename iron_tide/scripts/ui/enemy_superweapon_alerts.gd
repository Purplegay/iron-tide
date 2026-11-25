extends PanelContainer

const NOTICE_MS := 10000
var battle
var timers: Label
var launches: Label
var deadlines := {}
var friendly_launches: Label
var friendly_timers: Label
var friendly_deadlines := {}

func setup(world) -> void:
	battle = world
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UiKit.panel_style(Color("#241919ec"), Color("#cc684c"), 3, 1, 5))
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rows)
	launches = UiKit.make_label("", 17, Color("#ff9270"))
	timers = UiKit.make_label("", 14, Color("#ffd59e"))
	friendly_launches = UiKit.make_label("", 17, Color("#81dfff"))
	friendly_timers = UiKit.make_label("", 14, Color("#afe9ff"))
	for label in [launches, friendly_launches, timers, friendly_timers]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rows.add_child(label)
	battle.enemy_superweapon_launched.connect(_on_launch)
	battle.friendly_storm_launched.connect(_on_friendly_storm)
	refresh()

func _on_launch(weapon_name: String) -> void:
	deadlines[weapon_name] = Time.get_ticks_msec() + NOTICE_MS
	refresh()

func _on_friendly_storm(owner_label: String) -> void:
	friendly_deadlines[owner_label] = Time.get_ticks_msec() + NOTICE_MS
	refresh()

func _charge_text(seconds: float) -> String:
	if not is_finite(seconds): return "暂停"
	return "就绪" if seconds <= 0 else "%d:%02d" % [floori(seconds / 60), int(seconds) % 60]

func refresh() -> void:
	var remaining := {}
	var counts := {}
	var friendly_items := PackedStringArray()
	for source in battle.buildings:
		if not battle.actor_alive(source) or source.under_construction or not source.broadcasts_superweapon(): continue
		var friendly := BattleRequest.friendly("ally", source.side)
		if friendly and not source.is_allied_ai_storm(): continue
		if SupportSystems.charge_controller(source) != source: continue
		var label: String = source.sw_label()
		var seconds := INF
		var active := LightningStorm.active_for(battle, source)
		if source._superweapon_powered() and not active:
			seconds = ceilf(BattleClock.real_seconds(source.sw_recharge() - source._sw_charge))
		if friendly:
			friendly_items.append(label + " " + ("发动中" if active else _charge_text(seconds)))
			continue
		remaining[label] = minf(remaining.get(label, INF), seconds)
		counts[label] = int(counts.get(label, 0)) + 1
	var items := PackedStringArray()
	for label in remaining:
		var seconds: float = remaining[label]
		var state := _charge_text(seconds)
		var count_text := "×%d" % counts[label] if counts[label] > 1 else ""
		items.append("%s%s %s" % [label, count_text, state])
	timers.text = "敌方战略武器　" + "　·　".join(items)
	timers.visible = not items.is_empty()
	var now := Time.get_ticks_msec()
	for label in deadlines.keys():
		if now >= int(deadlines[label]): deadlines.erase(label)
	launches.text = "警报　敌方已发动：" + "、".join(deadlines.keys())
	launches.visible = not deadlines.is_empty()
	friendly_timers.text = "友方战略武器　" + "　·　".join(friendly_items)
	friendly_timers.visible = not friendly_items.is_empty()
	var friendly_text := PackedStringArray()
	for owner_label in friendly_deadlines.keys():
		if now >= int(friendly_deadlines[owner_label]): friendly_deadlines.erase(owner_label)
		else: friendly_text.append(owner_label + "已发动闪电风暴")
	friendly_launches.text = "　·　".join(friendly_text)
	friendly_launches.visible = not friendly_text.is_empty()
	visible = not battle.ended and (timers.visible or launches.visible or friendly_timers.visible or friendly_launches.visible)
