extends Node

const SavePanel = preload("res://scripts/ui/save_panel.gd")
var checks := 0
var failures := 0

func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", title)

func _ready() -> void:
	var isolation := OS.get_environment("IRON_SAVE_TEST_DIR").replace("\\", "/").trim_suffix("/")
	if isolation.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(isolation + "/"):
		push_error("Refusing to write saves without an isolated user directory")
		get_tree().quit(2)
		return
	await get_tree().process_frame
	var expected := ["auto", "quick"]
	for i in range(1, 11): expected.append("slot%d" % i)
	check(BattleSaves.SLOTS == expected, "ten manual slots in numeric order plus auto and quick")
	check(BattleSaves.slot_path("slot11").is_empty(), "slot 11 rejected")
	var paths := {}
	for slot in expected:
		var path := BattleSaves.slot_path(slot)
		check(path == "user://battles/%s.itsave" % slot and not paths.has(path), slot + " has its own file")
		paths[path] = true
	BattleRequest.configure_skirmish(MatchRules.RA2, {"map_size": 2400, "starting_funds": 8000, "enemy_base": "allied", "fog_of_war": false})
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1067, 600)
	viewport.world_2d = World2D.new()
	add_child(viewport)
	var screen = load("res://scenes/battle.tscn").instantiate()
	viewport.add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var world = screen.battle
	var old_hashes := {}
	for slot in ["auto", "quick", "slot1", "slot2", "slot3"]:
		check(BattleSaves.save_slot(world, slot).ok, slot + " existing save fixture")
		old_hashes[slot] = FileAccess.get_sha256(BattleSaves.slot_path(slot))
	var panel := SavePanel.new()
	panel.battle = world
	viewport.add_child(panel)
	panel.open()
	await get_tree().process_frame
	await get_tree().process_frame
	check(panel.slot_buttons.keys() == expected and panel.slot_buttons.auto.save.disabled, "battle panel lists all slots, auto read-only")
	var last: Dictionary = panel.slot_buttons.slot10
	var bar := panel.slots_scroll.get_v_scroll_bar()
	check(bar.visible and panel.slots_scroll.get_global_rect().end.y < viewport.size.y, "short viewport keeps the scroll list inside the screen")
	bar.value = bar.max_value
	await get_tree().process_frame
	var button_center: Vector2 = last.save.get_global_rect().get_center()
	check(panel.slots_scroll.get_global_rect().has_point(button_center), "scroll reaches slot 10 save button")
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = button_center
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		viewport.push_input(event, true)
	var saved := BattleSaves.read_slot("slot10")
	check(saved.ok and not last.load.disabled and last.caption.text.begins_with("手动存档 10"), "clicking slot 10 writes a readable save")
	var first_hash := FileAccess.get_sha256(BattleSaves.slot_path("slot10"))
	world.funds = 4321
	check(BattleSaves.save_slot(world, "slot10").ok and not first_hash.is_empty() and FileAccess.get_sha256(BattleSaves.slot_path("slot10") + ".bak") == first_hash, "slot 10 overwrite backs up the previous save")
	for slot in old_hashes:
		check(BattleSaves.read_slot(slot).ok and FileAccess.get_sha256(BattleSaves.slot_path(slot)) == old_hashes[slot], slot + " remains readable and unchanged")
	world.funds = 1234
	var prepared := BattleSaves.prepare_load("slot10")
	if prepared.ok: BattleSaves.restore_pending(world)
	check(prepared.ok and world.funds == 4321, "slot 10 restores saved battle funds")
	panel.free()
	var menu_panel := SavePanel.new()
	viewport.add_child(menu_panel)
	menu_panel.open()
	check(menu_panel.slot_buttons.keys() == expected and menu_panel.slot_buttons.slot10.save.disabled and not menu_panel.slot_buttons.slot10.load.disabled, "menu panel can load slot 10, not save to it")
	menu_panel.close()
	get_tree().paused = false
	viewport.free()
	print("SAVE SLOTS checks=", checks, " failed=", failures)
	get_tree().quit(0 if failures == 0 else 1)
