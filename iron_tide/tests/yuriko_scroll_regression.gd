extends Node

const JOURNAL := preload("res://scenes/yuriko_school.tscn")
const CG := preload("res://scripts/screens/yuriko_cg.gd")
const BOOK := preload("res://scripts/units/yuriko_school.gd")
const POSITIONS := {0: 31, 1: 56, 2: 77, 4: 93, 5: 123, 6: 145, 7: 160, 8: 182}
var failures := 0
var checks := 0

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", reason)

func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	run.call_deferred()

func settle() -> void:
	for i in 4:
		await get_tree().process_frame

func page(view, section: int) -> ScrollContainer:
	view.hub(section)
	var scroll: ScrollContainer = view.stage.find_child("PageScroll", true, false)
	# Ensure even the short, empty-profile lists can exercise scrolling.
	scroll.get_child(0).custom_minimum_size.y = 1600
	await settle()
	return scroll

func click(view, title: String) -> bool:
	for item: Button in view.stage.find_children("*", "Button", true, false):
		if item.text == title and not item.disabled:
			item.pressed.emit()
			return true
	return false

func run() -> void:
	var view = JOURNAL.instantiate()
	add_child(view)
	if "--verify" not in OS.get_cmdline_user_args():
		for section: int in POSITIONS:
			var scroll := await page(view, section)
			check(scroll.scroll_vertical == 0, "fresh page %d starts at top" % section)
			scroll.get_v_scroll_bar().value = POSITIONS[section]
		for section: int in POSITIONS:
			var scroll := await page(view, section)
			check(scroll.scroll_vertical == POSITIONS[section], "tab round trip %d: %d" % [section, scroll.scroll_vertical])
		MetaProgress.yuriko_school = {"pages": 8}
		await page(view, 0)
		view.read_episode(BOOK.episodes[0])
		check(click(view, "收起手记"), "return from reading an episode")
		await settle()
		var chapters: ScrollContainer = view.stage.find_child("PageScroll", true, false)
		check(chapters.scroll_vertical == POSITIONS[0], "chapter offset survives reading without padding")
		MetaProgress.yuriko_school["cg_album"] = {"same_stop": true}
		await page(view, 8)
		CG.show_page(view, 0, 0, false)
		check(click(view, "返回 CG 集"), "return from CG playback")
		await settle()
		var short_page: ScrollContainer = view.stage.find_child("PageScroll", true, false)
		check(short_page.scroll_vertical < POSITIONS[8], "short CG list clamps to available range")
		var restored := await page(view, 8)
		check(restored.scroll_vertical == POSITIONS[8], "clamping did not erase the saved CG offset")
		await get_tree().create_timer(0.4).timeout
		check(FileAccess.file_exists(view.SCROLL_PREFS_PATH), "debounced save wrote preferences")
		# Scene removal must flush a change without waiting for the debounce timer.
		restored.get_v_scroll_bar().value = POSITIONS[8] + 10
		remove_child(view)
		view.queue_free()
	else:
		for section: int in POSITIONS:
			var scroll := await page(view, section)
			var expected: int = POSITIONS[section] + (10 if section == 8 else 0)
			check(scroll.scroll_vertical == expected, "cold restart %d: %d, expected %d" % [section, scroll.scroll_vertical, expected])
	print("yuriko scroll: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
