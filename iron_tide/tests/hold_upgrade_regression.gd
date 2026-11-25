extends Node
const Hold = preload("res://scripts/ui/hold_upgrade_button.gd")
const Academy = preload("res://scripts/rules/academy.gd")
var checks: Array = []
var failed := 0
var button: Button
var hero := "E1"
var track := "firepower"
var purchases := 0
var stage := SubViewport.new()

func check(ok: bool, label: String) -> void:
	checks.append({"name": label, "passed": ok})
	if not ok:
		failed += 1
		print("FAIL ", label)

func rank() -> int:
	return Academy.training_rank(MetaProgress.academy.get("hero_training", {}), hero, track)

func update_button() -> void:
	button.disabled = rank() >= Academy.training_cap(track) or MetaProgress.balance("credits") < Academy.hero_training_cost(rank())

func purchase() -> bool:
	var ok := Academy.purchase(MetaProgress, track, hero)
	if ok: purchases += 1
	return ok

func mouse(down: bool, position := Vector2(100, 70)) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	Input.parse_input_event(motion)
	stage.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	stage.push_input(event, true)

func step(seconds: float) -> void:
	button._process(seconds)

func reset_training(level := 0, credits := 10000000) -> void:
	button.cancel_hold()
	mouse(false)
	button.show()
	MetaProgress.academy.hero_training = {hero: {track: level}}
	MetaProgress.currency.credits = credits
	update_button()

func _ready() -> void:
	if not OS.get_user_data_dir().contains("CodexIronTideValidation") or OS.get_environment("IRON_TIDE_REPORT_DIR").is_empty():
		get_tree().quit(2)
		return
	call_deferred("run")

func run() -> void:
	MetaProgress.reset_save()
	MetaProgress.academy.hero_builds = {"E1": 50, "E2": 50}
	stage.size = Vector2i(1200, 900)
	stage.gui_disable_input = false
	add_child(stage)
	button = Hold.new()
	button.position = Vector2(40, 40)
	button.size = Vector2(600, 80)
	button.text = "Training"
	button.purchase = purchase
	stage.add_child(button)
	button.set_process(false)
	Events.meta_changed.connect(update_button)
	await get_tree().process_frame
	reset_training()
	var wallet := MetaProgress.balance("credits")
	mouse(true)
	check(button._holding and button.progress.visible, "real mouse press begins visible progress")
	step(0.2)
	mouse(false)
	check(rank() == 1 and not button.progress.visible, "short click purchases one level on release")
	check(MetaProgress.balance("credits") == wallet - Academy.hero_training_cost(0), "single click uses real purchase price")
	reset_training()
	wallet = MetaProgress.balance("credits")
	mouse(true)
	step(1.0)
	check(rank() == 0 and is_equal_approx(button.progress.value, 0.5), "first hold fills progress before charging")
	step(1.0)
	check(rank() == 1, "first upgrade after two seconds")
	step(1.0)
	check(rank() == 1 and is_equal_approx(button.progress.value, 1.0 / 1.5), "second interval accelerates to 1.5 seconds")
	step(0.5)
	check(rank() == 2, "second repeat completed")
	for i in 4:
		step(0.9)
		check(rank() == i + 2, "steady interval does not fire early %d" % i)
		step(0.1)
		check(rank() == i + 3, "steady interval one second %d" % i)
	var spent := 0
	for i in 6: spent += Academy.hero_training_cost(i)
	check(MetaProgress.balance("credits") == wallet - spent, "each level charges its current price")
	mouse(false)
	check(rank() == 6 and not button.progress.visible, "release after repeats does not buy an extra level")
	MetaProgress.load_save()
	check(rank() == 6 and MetaProgress.balance("credits") == wallet - spent, "rank and wallet persisted by real save path")
	mouse(true)
	step(1.0)
	check(rank() == 6, "next hold resets acceleration")
	button.mouse_exited.emit()
	step(10.0)
	mouse(false, Vector2(800, 300))
	check(rank() == 6 and not button.progress.visible, "pointer exit cancels without release purchase")
	mouse(true)
	button.hide()
	step(10.0)
	mouse(false)
	check(rank() == 6 and not button.progress.visible, "hiding page cancels immediately")
	button.show()
	mouse(true)
	get_window().focus_exited.emit()
	step(10.0)
	mouse(false)
	check(rank() == 6, "losing window focus cancels without late click")
	reset_training(0, Academy.hero_training_cost(0))
	mouse(true)
	step(2.0)
	step(10.0)
	mouse(false)
	check(rank() == 1 and MetaProgress.balance("credits") == 0 and not button._holding, "insufficient next-level funds stop repeats")
	for selected_track in ["firepower", "health"]:
		track = selected_track
		var cap := Academy.training_cap(track)
		reset_training(cap - 1)
		mouse(true)
		step(2.0)
		step(10.0)
		mouse(false)
		check(rank() == cap and button.disabled and not button._holding, "cap stops " + track)
	track = "firepower"
	reset_training()
	mouse(true)
	step(30.0)
	check(rank() == 1, "slow frame never catches up a burst of purchases")
	mouse(false)
	reset_training()
	# Force a real atomic-save failure using a directory at the temporary-file path.
	DirAccess.make_dir_absolute(MetaProgress.SAVE_PATH + ".tmp")
	wallet = MetaProgress.balance("credits")
	mouse(true)
	step(2.0)
	check(rank() == 0 and MetaProgress.balance("credits") == wallet and not button._holding, "failed save rolls back and stops hold")
	mouse(false)
	check(rank() == 0, "release after failed save does not retry")
	DirAccess.remove_absolute(MetaProgress.SAVE_PATH + ".tmp")
	# Check the actual hero page wiring and cancellation when switching heroes.
	var page = preload("res://scripts/ui/hero_progression.gd").new()
	page.selected = "E1"
	add_child(page)
	page.picker.add_item("E2")
	page.picker.set_item_metadata(0, "E2")
	page.firepower._holding = true
	page.health._holding = true
	page.picker.item_selected.emit(0)
	check(not page.firepower._holding and not page.health._holding and page.selected == "E2", "hero switch cancels both training holds")
	MetaProgress.currency.credits = 10000000
	check(page.firepower.purchase.call() and Academy.training_rank(MetaProgress.academy.hero_training, "E2", "firepower") == 1, "actual firepower UI calls selected hero purchase")
	check(page.health.purchase.call() and Academy.training_rank(MetaProgress.academy.hero_training, "E2", "health") == 1, "actual health UI calls selected hero purchase")
	page.queue_free()
	await get_tree().process_frame
	FileAccess.open(OS.get_environment("IRON_TIDE_REPORT_DIR").path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failed": failed}))
	print("HOLD_UPGRADE checks=", checks.size(), " failed=", failed)
	get_tree().quit(failed)
