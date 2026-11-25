extends ScrollContainer

const TASKS := preload("res://scripts/rules/academy.gd").DIAMOND_TASKS
var summary:Label
var rows := {}

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(column)
	column.add_child(UiKit.make_label("每日任务", 23, UiKit.COL_ACCENT_2))
	summary=preload("res://scripts/ui/resource_cost_icon.gd").balance_label(column,"diamonds","",15,UiKit.COL_TEXT)
	for key in TASKS:
		var task: Dictionary = TASKS[key]
		var panel := UiKit.make_panel()
		column.add_child(panel)
		var box := VBoxContainer.new()
		panel.add_child(box)
		var header := HBoxContainer.new()
		box.add_child(header)
		var title := UiKit.make_label(task.title,17,UiKit.COL_TEXT)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(title)
		preload("res://scripts/ui/resource_cost_icon.gd").balance_label(header,"diamonds","+%d 钻石"%task.reward,16,UiKit.COL_GOLD)
		var bar := ProgressBar.new()
		bar.max_value = task.goal
		bar.show_percentage = false
		bar.custom_minimum_size.y = 10
		box.add_child(bar)
		var state := UiKit.make_label("",14,UiKit.COL_DIM)
		box.add_child(state)
		rows[key] = {"bar":bar,"state":state}
	var hint := UiKit.make_label("经典与扩展遭遇战共用进度。奖励达成时自动到账，每天按本机时间 00:00 刷新。",14,UiKit.COL_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)

func refresh() -> void:
	var daily := MetaProgress.Academy.today(MetaProgress)
	var earned := 0
	var total := 0
	for key in TASKS:
		var task: Dictionary = TASKS[key]
		var row: Dictionary = rows[key]
		var count := clampi(int(daily.get(key,0)),0,task.goal)
		var complete: bool = count == task.goal
		row.bar.value = count
		row.state.text = "%d / %d　·　%s" % [count,task.goal,"已到账" if complete else "进行中"]
		row.state.modulate = UiKit.COL_OK if complete else Color.WHITE
		total += int(task.reward)
		if complete: earned += int(task.reward)
	summary.text = "%s　·　今日已获 %d / %d 钻石" % [daily.date,earned,total]
