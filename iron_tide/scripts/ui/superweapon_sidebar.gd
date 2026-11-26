extends PanelContainer
## One live button per launcher. A captured second launcher retains its own charge.
const WEAPONS := {
	"ChronoSphere": ["超时空转换","CHROICON"],
	"LightningStorm": ["闪电风暴","BOLTICON"],
	"ForceShield": ["力场护盾","FORCICON"],
	"IronCurtain": ["铁幕","IRCRICON"],
	"MultiMissile": ["核弹攻击","NUKEICON"],
	"SpyPlane": ["侦察机","SPYPICON"],
	"AmerParaDrop": ["美国大兵空降","APARICON"],
	"ParaDrop": ["机场伞兵援助","PARAICON"],
}
const WIDTH := 84
const HEIGHT := 40
var battle
var grid := GridContainer.new()
var buttons := {}

class ChargeMask extends ProgressBar:
	func _init() -> void:
		name = "Charge"
		set_meta("ra3_skip", true)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_percentage = false
		fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
		max_value = 1.0
		step = 1.0 / 256.0
		add_theme_stylebox_override("background", StyleBoxEmpty.new())
		var shade := StyleBoxFlat.new()
		shade.bg_color = Color("#34586f80")
		shade.border_color = Color("#96dcf4b8")
		shade.border_width_top = 1
		add_theme_stylebox_override("fill", shade)
		hide()

	func set_remaining(fraction: float) -> void:
		visible = fraction > 0.0
		value = maxf(step, fraction) if visible else 0.0

func setup(world) -> void:
	battle = world
	name = "SuperweaponSidebar"
	self_modulate.a = 0.56
	add_theme_stylebox_override("panel",UiKit.ra_style(UiKit.RA_PANEL,UiKit.RA_EDGE,3,4,true))
	var column := VBoxContainer.new()
	add_child(column)
	column.add_child(UiKit.ra_label("战略支援",12,UiKit.RA_CYAN))
	grid.add_theme_constant_override("h_separation",2)
	grid.add_theme_constant_override("v_separation",2)
	column.add_child(grid)
	hide()

func make_support_button() -> Button:
	var item := UiKit.make_button("",11)
	item.custom_minimum_size = Vector2(WIDTH,HEIGHT)
	item.focus_mode = Control.FOCUS_NONE
	item.clip_text = true
	item.expand_icon = true
	item.add_theme_constant_override("icon_max_width",22)
	item.add_theme_color_override("font_disabled_color", Color("#cfdae3"))
	grid.add_child(item)
	var charge := ChargeMask.new()
	item.add_child(charge)
	charge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	charge.offset_left = 4
	charge.offset_right = -4
	charge.offset_top = 3
	charge.offset_bottom = -3
	return item

func refresh() -> void:
	if battle.command_mode == "superweapon":
		var source = battle._armed_superweapon
		if not battle.owns_superweapon(source) or not source.sw_ready(): battle.arm_command("")
	var present := {}
	for source in battle.buildings:
		if not battle.owns_superweapon(source) or source.under_construction: continue
		if SupportSystems.charge_controller(source) != source: continue
		var id: int = source.get_instance_id()
		present[id] = true
		var item: Button = buttons.get(id)
		var entry: Array = WEAPONS.get(source.sw_type(), [source.sw_label(),""])
		if item == null:
			item = make_support_button()
			item.toggle_mode = true
			var path := "res://assets/ra2/cameo/%s.png" % entry[1] if entry[1] != "" else GameData.ra2_cameo_path(source.building_id)
			if ResourceLoader.exists(path): item.icon = load(path)
			item.pressed.connect(_activate.bind(source))
			buttons[id] = item
		var ready: bool = source.sw_ready()
		var aiming: bool = battle.command_mode=="superweapon" and battle._armed_superweapon==source
		var state := "就绪"
		if aiming: state = "选目标"
		elif source._buildup_play >= 0: state = "展开中"
		elif not source._superweapon_powered(): state = "未供能" if battle.side_power_low(source.side) else "离线"
		elif not ready:
			var seconds := ceili(BattleClock.real_seconds(source.sw_recharge() - source._sw_charge))
			state = "%d:%02d" % [floori(seconds/60.0),seconds%60]
		var charge: ChargeMask = item.get_node("Charge")
		charge.set_remaining(1.0 - source.sw_progress())
		item.text = "%s\n%s" % [entry[0],state]
		item.set_pressed_no_signal(aiming)
		item.disabled = not ready or battle.paused or battle.ended
		item.tooltip_text = "%s · %s（%d，%d）\n%s" % [entry[0],source.display_name,roundi(source.position.x),roundi(source.position.y),"点击后在地图选取目标，右键或 Esc 取消" if ready else state]
	for id in buttons.keys():
		if not present.has(id):
			var old: Button = buttons[id]
			grid.remove_child(old)
			old.queue_free()
			buttons.erase(id)
	visible = grid.get_child_count() > 0 and not battle.ended

func _activate(source) -> void:
	if not battle.owns_superweapon(source) or not source.sw_ready() or battle.paused or battle.ended: return
	if battle.command_mode=="superweapon" and battle._armed_superweapon==source:
		battle.arm_command("")
	else:
		battle.arm_superweapon(source)
	refresh()

func arrange(origin: Vector2, available_width: float) -> void:
	if not visible: return
	position = origin
	var frame := get_theme_stylebox("panel").get_minimum_size()
	var gap := grid.get_theme_constant("h_separation")
	var capacity := floori((available_width - frame.x + gap) / (WIDTH + gap))
	grid.columns = clampi(capacity, 1, maxi(1, grid.get_child_count()))
	reset_size()
