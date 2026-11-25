extends VBoxContainer
const IDS := ["aggressive", "defend", "guard", "return_fire", "hold_fire"]
const STATES := {"aggressive":"free", "defend":"defend", "guard":"guard", "return_fire":"return", "hold_fire":"none"}
const NAMES := {"aggressive":"主动进攻", "defend":"自动防卫", "guard":"原地警戒", "return_fire":"仅反击", "hold_fire":"停火"}
const SHORT := {"aggressive":"进攻", "defend":"防卫", "guard":"固守", "return_fire":"反击", "hold_fire":"停火"}
const TIPS := {
	"aggressive":"主动索敌并追击。再按 V 或再点此图标：关闭，恢复自动防卫。保留手动移动／攻击指令。",
	"defend":"自动攻击射程内的敌方单位；待命受击时可短距离追击攻击者。保留手动移动／攻击指令。",
	"guard":"停止移动，原地攻击射程内的目标。再按 G 或再点此图标：恢复自动防卫。部署／卧倒状态不变。",
	"return_fire":"只自动反击攻击者，不主动找敌人。保留手动移动／攻击指令。",
	"hold_fire":"停止当前射击，不自动开火；继续已有移动。之后手动指定攻击目标仍会开火。",
}
var hud
var status: Label
var buttons: Dictionary = {}

func setup(owner_hud) -> void:
	hud = owner_hud
	name = "CombatStanceBar"
	status = UiKit.make_label("作战姿态", 11, UiKit.COL_DIM)
	add_child(status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	add_child(row)
	for id: String in IDS:
		var button := UiKit.ra_icon_tile(40)
		button.name = "Stance_" + id
		button.set_meta("ra3_skip", true)
		button.toggle_mode = true
		var icon := TextureRect.new()
		icon.texture = load("res://assets/ra3/ui/commands/" + id + ".png")
		icon.position = Vector2(7, 1)
		icon.size = Vector2(26, 22)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		var label := UiKit.make_label(SHORT[id], 11)
		label.position = Vector2(0, 22)
		label.size = Vector2(40, 17)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(label)
		var hotkey := UiKit.make_label("", 9, UiKit.RA_CYAN)
		hotkey.position = Vector2(30, 0)
		hotkey.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(hotkey)
		button.set_meta("hotkey_label", hotkey)
		button.set_meta("base_tooltip", NAMES[id] + "\n" + TIPS[id])
		button.pressed.connect(hud._cmd.bind(id))
		buttons[id] = button
		hud.cmd_buttons[id] = button
		row.add_child(button)
	refresh()

func refresh() -> void:
	var state: String = hud.battle.selected_fire_stance()
	var label := "未选择部队" if state.is_empty() else "混合姿态（点击统一设置）"
	for id: String in IDS:
		var button: Button = buttons[id]
		var active: bool = state == STATES[id]
		var partial := false
		if state == "mixed":
			for unit in hud.battle.selected_units:
				if not hud.battle.actor_alive(unit) or unit.side != "ally" or unit.embarked_in != null: continue
				var current: String = "guard" if unit.hold_position and unit.fire_stance == "free" else unit.fire_stance
				partial = partial or current == STATES[id]
		button.set_pressed_no_signal(active)
		button.disabled = state.is_empty()
		button.get_meta("hotkey_label").text = hud._cmd_hotkey(id)
		var enabled := "已开启" if active else ("部分开启" if partial else "已关闭")
		button.tooltip_text = hud.Hotkeys.hint(NAMES[id] + " · " + enabled + "\n" + TIPS[id])
		if active: label = NAMES[id]
	status.text = "作战姿态：" + label
