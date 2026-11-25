extends Button
## Each repeat uses the caller's normal, persisted single-level purchase.
const INTERVALS := [2.0, 1.5, 1.0]
var purchase := Callable()
var progress := ProgressBar.new()
var _holding := false
var _elapsed := 0.0
var _repeats := 0
var _suppress_click := false

func _ready() -> void:
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	tooltip_text = "点击升一级；长按连续升级：2 秒 → 1.5 秒 → 每秒一级。松手或移开鼠标停止。"
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.show_percentage = false
	progress.max_value = 1.0
	progress.step = 0.0
	progress.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	progress.offset_top = -5.0
	progress.offset_bottom = 0.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("59d7ee")
	progress.add_theme_stylebox_override("fill", fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("19303c")
	progress.add_theme_stylebox_override("background", background)
	add_child(progress)
	progress.hide()
	button_down.connect(_begin_hold)
	button_up.connect(_release_hold)
	pressed.connect(_click)
	mouse_exited.connect(cancel_hold)
	visibility_changed.connect(func():
		if not is_visible_in_tree(): cancel_hold())
	get_window().focus_exited.connect(cancel_hold)

func _begin_hold() -> void:
	_suppress_click = false
	_elapsed = 0.0
	_repeats = 0
	_holding = not disabled and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	progress.value = 0.0
	progress.visible = _holding

func _release_hold() -> void:
	_holding = false
	progress.hide()

func cancel_hold() -> void:
	if _holding: _suppress_click = true
	_release_hold()

func _click() -> void:
	if _suppress_click:
		_suppress_click = false
		return
	if not disabled and is_visible_in_tree() and purchase.is_valid():
		purchase.call()

func _process(delta: float) -> void:
	if not _holding: return
	if disabled or not is_visible_in_tree() or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		cancel_hold()
		return
	_advance_hold(delta)

func _advance_hold(delta: float) -> void:
	if not _holding: return
	_elapsed += delta
	var interval: float = INTERVALS[mini(_repeats, INTERVALS.size() - 1)]
	progress.value = minf(_elapsed / interval, 1.0)
	if _elapsed < interval: return
	# Suppress the release click before purchase: a refresh may disable this button.
	_suppress_click = true
	if not purchase.is_valid() or not bool(purchase.call()):
		cancel_hold()
		return
	_repeats += 1
	# No catch-up burst after a slow frame or a synchronous save.
	_elapsed = 0.0
	progress.value = 0.0
	if disabled or not is_visible_in_tree(): cancel_hold()
