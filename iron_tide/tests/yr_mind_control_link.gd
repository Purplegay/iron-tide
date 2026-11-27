extends Node

const Link = preload("res://scripts/core/yr_mind_control_link.gd")
const Psychic = preload("res://scripts/world/yuri_support.gd")
var checks := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed += 1
	print(("通过：" if ok else "失败：") + label)

func _ready() -> void:
	run.call_deferred()

func prior_point(from: Vector2, to: Vector2, i: int) -> Vector2:
	var t := float(i) / 32.0
	var centered := 2.0 * t - 1.0
	return from.lerp(to, t) + Vector2.UP * (512.0 * Link.HEIGHT * (1.0 - centered * centered))

func prior_payload(ends: PackedVector2Array, base: Color, ms: int) -> Array:
	var lines := PackedVector2Array()
	var colors := PackedColorArray()
	lines.resize(64)
	colors.resize(32)
	var previous := ends[0]
	for i in range(1, 33):
		var next := prior_point(ends[0], ends[1], i)
		lines[2 * (i - 1)] = previous
		lines[2 * i - 1] = next
		colors[i - 1] = Link.segment_color(base, i, ms)
		previous = next
	return [lines, colors]

func payload_regression(ends: PackedVector2Array) -> void:
	var all_equal := true
	for c in range(20): # Force palette eviction, then revisit the first colors.
		var base := Color(0.85, c / 20.0, 0.4, 0.85)
		for phase in range(65):
			var moving := PackedVector2Array([ends[0], ends[1] + Vector2(phase, -c)])
			var ms := phase * 16 + 15
			var old := prior_payload(moving, base, ms)
			if old != [Link.link_segments(moving), Link.link_colors(base, ms)]: all_equal = false
	var original_color := Color(0.85, 0.0, 0.4, 0.85)
	check(all_equal and prior_payload(ends, original_color, 1024) == [Link.link_segments(ends), Link.link_colors(original_color, 1024)], "1301 组移动端点、房色及高光相位逐值一致，含缓存淘汰")
	if not OS.get_cmdline_user_args().has("--bench"): return
	var colors := [Color.RED, Color.BLUE, Color.PURPLE, Color.YELLOW]
	for optimized in [false, true, true, false]:
		var checksum := 0.0
		var started := Time.get_ticks_usec()
		for i in range(16000):
			var base: Color = colors[i & 3]
			var payload := [Link.link_segments(ends), Link.link_colors(base, i)] if optimized else prior_payload(ends, base, i)
			checksum += payload[0][i & 63].y + payload[1][i & 31].r
		print("心控绘制数据 %s：%d us / 16000 条，校验和 %.3f" % ["B" if optimized else "A", Time.get_ticks_usec() - started, checksum])

func run() -> void:
	var tree := get_tree()
	reparent(tree.root)
	var menu = load("res://scenes/campaign_command.tscn").instantiate()
	tree.root.add_child(menu)
	for btn in menu.find_children("*", "Button", true, false):
		if btn.text == "苏军战役": btn.pressed.emit(); break
	for btn in menu.find_children("*", "Button", true, false):
		if btn.text == "首脑游戏": btn.pressed.emit(); break
	var launch: Array = menu.page.find_children("*", "Button", true, false).filter(func(b): return b.text == "出击")
	check(menu.mission.get("id") == "yr_head_games" and not launch.is_empty(), "打开首脑游戏简报")
	if failed:
		tree.quit(1)
		return
	launch[0].pressed.emit()
	await tree.scene_changed
	var world: Battle = tree.current_scene.battle
	world.paused = true
	var p := Vector2(2600, 2600)
	var y: Unit = world.spawn_unit("YURI", "ally", p)
	var tank: Unit = world.spawn_unit("MTNK", "enemy", p + Vector2(140, 0))
	var mind: Unit = world.spawn_unit("MIND", "ally", p + Vector2(0, 250))
	var second: Unit = world.spawn_unit("HTNK", "enemy", p + Vector2(160, 250))
	var prime: Unit = world.spawn_unit("YURIPR", "ally", p + Vector2(0, 475))
	var site: Building = world._place_building("GAPOWR", "enemy", p + Vector2(160, 475), true)
	check(y != null and tank != null and mind != null and second != null and prime != null and site != null, "实载三种心控单位及目标")
	if failed:
		tree.quit(1)
		return
	y.attack_target = tank
	y._fire_shot(tank, true)
	check(Psychic.visible_control_source(world, tank, {}) == y and tank.side == y.side, "开火转属并立刻显示弧线，无需选中")
	if failed:
		tree.quit(1)
		return
	var ends := Link.endpoints(y, tank, true)
	check(Link.point(ends[0], ends[1], 0) == ends[0] and Link.point(ends[0], ends[1], 32) == ends[1], "32 段连到两端")
	check(is_equal_approx((ends[0].lerp(ends[1], 0.5) - Link.point(ends[0], ends[1], 16)).y, 512.0 * Link.HEIGHT), "中点抬高 512 lepton")
	check(Link.segment_color(Color.RED, 4, 0) != Link.segment_color(Color.RED, 4, 16), "高光每 16 毫秒移动一段")
	payload_regression(ends)
	var old_end: Vector2 = ends[1]
	tank.global_position += Vector2(8, 30)
	check((Link.endpoints(y, tank, true)[1] - old_end).is_equal_approx(Iso.dir(Vector2(8, 30))), "受控者移动时弧线端点跟随")
	world.paused = false
	AlliedAbilities.tick_actor(tank, 5.0)
	check(not y.selected and not tank.selected and Psychic.visible_control_source(world, tank, {}) == y, "超过旧时限后无需选中，仍显示心控弧线")
	world.paused = true
	world.center_on(p)
	world.hp_overlay.queue_redraw()
	await tree.process_frame
	await tree.process_frame
	check(Psychic.visible_control_source(world, tank, {}) == y, "暂停时仍可查看心控关系")
	var origin: String = tank.special.original_side
	tank.special["mind_control_link_left"] = 0.0
	check(Psychic.visible_control_source(world, tank, {}) == y, "旧档计时已归零也不会藏线")
	AlliedAbilities.release_control(y)
	check(Psychic.visible_control_source(world, tank, {}) == null and tank.side == origin and not tank.special.has("mind_control_link_left"), "解控撤线、清旧字段、恢复阵营")
	mind.attack_target = tank
	mind._fire_shot(tank, true)
	mind.attack_target = second
	mind._fire_shot(second, true)
	check(Psychic.visible_control_source(world, tank, {}) == mind and Psychic.visible_control_source(world, second, {}) == mind and Link.endpoints(mind, tank, true)[0] != Link.endpoints(mind, second, true)[0], "精神控制车同时两条弧线各用不同起点")
	prime.attack_target = site
	prime._fire_shot(site, true)
	check(Psychic.visible_control_source(world, site, {}) == prime, "尤里改控制建筑时显示弧线")
	var hostile: Unit = world.spawn_unit("MIND", "enemy", p + Vector2(500, 600))
	var hidden: Unit = world.spawn_unit("MTNK", "ally", p + Vector2(550, 600))
	AlliedAbilities.apply_mind_control(hostile, hidden)
	var old_cells: PackedByteArray = world.fog.visible_cells["ally"]
	var lit := old_cells.duplicate()
	lit.fill(1)
	world.fog.visible_cells["ally"] = lit
	check(not hostile.selected and not hidden.selected and Psychic.visible_control_source(world, hidden, {}) == hostile, "敌方心控原己方单位后，两端可见就显示弧线")
	var blank := PackedByteArray()
	blank.resize(old_cells.size())
	world.fog.visible_cells["ally"] = blank
	check(Psychic.control_source(hidden, {}) == hostile and Psychic.visible_control_source(world, hidden, {}) == null, "迷雾内不通过弧线泄漏敌方心控位置")
	world.fog.visible_cells["ally"] = old_cells
	world.paused = true
	var codec = preload("res://scripts/save/battle_snapshot.gd").new()
	var snapshot: Dictionary = codec.capture(world)
	var fields: Dictionary = codec.records[codec.ids[site]].fields
	var control: Dictionary = codec.decode(fields.special)
	check(BattleSaves.validate(snapshot).is_empty() and control.get("controller") == prime and not control.has("mind_control_link_left"), "新快照保留控制关系，不再写入计时")
	mind._die()
	check(Psychic.visible_control_source(world, tank, {}) == null and Psychic.visible_control_source(world, second, {}) == null, "控制者死亡后两条线都撤掉")
	print("心控弧线回归：%d/%d 通过" % [checks - failed, checks])
	tree.quit(int(failed > 0))
