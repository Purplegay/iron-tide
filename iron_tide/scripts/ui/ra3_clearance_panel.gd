extends VBoxContainer
## Independent match-local Allied clearance UI, separate from permanent progression.
var base
var status: Label
var purchase: Button
var progress: ProgressBar

func setup(building) -> void:
	base = building
	status = Label.new()
	status.add_theme_font_size_override("font_size", 13)
	add_child(status)
	purchase = Button.new()
	purchase.custom_minimum_size = Vector2(240, 38)
	purchase.focus_mode = Control.FOCUS_NONE
	purchase.pressed.connect(func():
		var current := Ra3Clearance.state(base)
		if int(current.target) != 0:
			current.paused = false
			base.special[Ra3Clearance.KEY] = current
		else: Ra3Clearance.start(base))
	purchase.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			Ra3Clearance.right_click(base)
			accept_event())
	add_child(purchase)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 16
	add_child(progress)
	_process(0.0)

func _process(_delta: float) -> void:
	if not is_instance_valid(base): queue_free(); return
	var current := Ra3Clearance.state(base)
	status.text = "RA3 盟军许可 · T%d · 独立于尤复科技" % int(current.tier)
	var target := int(current.target)
	progress.visible = target > 0
	if target > 0:
		var rule: Dictionary = Ra3Clearance.TIERS[target]
		progress.value = float(current.elapsed) / float(rule.seconds) * 100.0
		purchase.text = ("继续" if current.paused else "升级中：") + str(rule.name) + "  %d%%" % int(progress.value)
		purchase.disabled = not current.paused
		# Disabled buttons still receive right-click GUI input in Godot.
		purchase.tooltip_text = "右键暂停，再次右键取消并退回已付资金；左键继续。"
	else:
		var next := mini(3, int(current.tier) + 1)
		var rule: Dictionary = Ra3Clearance.TIERS[next]
		purchase.text = "%s · %d · %ds" % [rule.name, int(rule.cost), int(rule.seconds)] if int(current.tier) < 3 else "最高许可已完成"
		var reason := Ra3Clearance.start_reason(base)
		purchase.disabled = not reason.is_empty()
		purchase.tooltip_text = reason if not reason.is_empty() else "为附近生产建筑提供 RA3 许可；未来坦克与先锋武装炮艇还需要作战实验室（兼防卫局）。"
