extends Node

const Wave := preload("res://scripts/core/yr_magnetic_wave.gd")
const Pull := preload("res://scripts/units/yr_magnetron_pull.gd")
var failed := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed += 1
	print(("通过：" if ok else "失败：") + label)

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	var tree := get_tree()
	reparent(tree.root)
	var menu = load("res://scenes/campaign_command.tscn").instantiate()
	tree.root.add_child(menu)
	for btn in menu.find_children("*", "Button", true, false):
		if btn.text == "苏军战役": btn.pressed.emit(); break
	for btn in menu.find_children("*", "Button", true, false):
		if btn.text == "首脑游戏": btn.pressed.emit(); break
	check(menu.mission.get("id") == "yr_head_games", "战役菜单选中首脑游戏")
	var launched := false
	for btn in menu.page.find_children("*", "Button", true, false):
		if btn.text == "出击":
			btn.pressed.emit()
			launched = true
			break
	check(launched, "从当前战役简报点击出击")
	if not launched:
		tree.quit(1)
		return
	await tree.scene_changed
	var world = tree.current_scene.battle
	world.paused = true
	var start := Vector2(2600, 2600)
	var gun: Unit = world.spawn_unit("TELE", "ally", start)
	var vehicle: Unit = world.spawn_unit("MTNK", "enemy", start + Vector2(280, 0))
	var building: Building = world._place_building("GAPOWR", "enemy", start + Vector2(0, 300), true)
	check(gun != null and vehicle != null and building != null and gun._ra2_tur.get("tex") != null, "战场载入磁电坦克炮塔与两个目标")
	if gun == null or vehicle == null or building == null:
		tree.quit(1)
		return
	var effects: Node = world.effects_root
	gun.attack_target = vehicle
	gun._fire_shot(vehicle, true)
	var wave = gun.get_meta(Wave.ACTIVE_WAVE) if gun.has_meta(Wave.ACTIVE_WAVE) else null
	check(wave is Wave and wave.reversed and vehicle.special.get("magnet_source") == gun and gun._muzzle == 0.0, "主武器建立牵引、使用反向磁力波而非炮口火光")
	if not wave is Wave:
		tree.quit(1)
		return
	var fx_count := effects.get_child_count()
	gun._fire_shot(vehicle, true)
	check(effects.get_child_count() == fx_count and gun.get_meta(Wave.ACTIVE_WAVE) == wave, "同一磁电坦克重复开火不叠波")
	check(wave.tail() == 0.0 and is_equal_approx(wave.head(), 0.0), "初始前沿位于起始端")
	wave._process(0.5)
	check(wave.tick_age == 0.0, "暂停不推进波面")
	world.paused = false
	wave._process(10.0 / Wave.RATE)
	check(is_equal_approx(wave.head(), 0.5), "十个规则帧推进至半程")
	var prev: Vector2 = wave.first
	vehicle.global_position += Vector2(12, 15)
	wave._process(10.0 / Wave.RATE)
	check(wave.first.is_equal_approx(prev + Vector2(12, 15)) and wave.head() == 1.0, "波面跟随牵引目标，二十帧到达另一端")
	check(not wave.visible, "迷雾中的两个端点不显示波面")
	var fog = world.fog
	world.fog = null
	wave._process(0.0)
	check(wave.visible and wave.copy.rect.has_area(), "两端可见时启用局部背景采样")
	world.fog = fog
	vehicle.special.erase("magnet_source")
	wave._process(0.0)
	wave._process(10.0 / Wave.RATE)
	check(wave.head() == 1.0 and is_equal_approx(wave.tail(), 0.5), "牵引解除时从起始端收波")
	wave._process(11.0 / Wave.RATE)
	check(wave.is_queued_for_deletion(), "磁力波收完移除")
	wave.free()
	check(not gun.has_meta(Wave.ACTIVE_WAVE), "清掉单波登记")
	gun.attack_target = building
	var hp: float = building.hp
	fx_count = effects.get_child_count()
	gun._fire_shot(building, true)
	wave = gun.get_meta(Wave.ACTIVE_WAVE) if gun.has_meta(Wave.ACTIVE_WAVE) else null
	check(wave is Wave and not wave.reversed and building.hp < hp and gun._muzzle == 0.0, "副武器正向画波并保留原建筑伤害")
	check(effects.get_child_count() == fx_count + 1, "副武器不再生成通用撞击圆圈")
	if wave is Wave:
		gun.attack_target = null
		wave._process(1.0 / Wave.RATE)
		wave._process(2.0 / Wave.RATE)
		check(wave.is_queued_for_deletion(), "停止攻击建筑后收波")
	if wave is Wave: wave.free()
	for i in 120:
		if vehicle.special.has(Pull.KEY): Pull.tick(vehicle, 1.0 / 60.0)
	var ground_pos := vehicle.global_position
	vehicle.attack_target = null
	gun.attack_target = vehicle
	gun._fire_shot(vehicle, true)
	wave = gun.get_meta(Wave.ACTIVE_WAVE) if gun.has_meta(Wave.ACTIVE_WAVE) else null
	var layer := vehicle.collision_layer
	for i in 60: vehicle._physics_process(1.0 / 60.0)
	check(vehicle._visual_lift() > 8.0 and vehicle.global_position.is_equal_approx(ground_pos), "命中后先垂直抬起，不再贴地滑动")
	world.fog._reveal("ally", vehicle.global_position, 110.0, 5.0)
	check(vehicle.is_air_target() and not vehicle.ground_contact_eligible() and vehicle.collision_layer == 0 and gun.attack_domain_valid(vehicle), "升空用空中目标层，不挡地面且磁电坦克不丢目标")
	if wave is Wave:
		wave._process(0.0)
		check(is_equal_approx(Iso.dir(wave.first - vehicle.global_position).y, -vehicle._visual_lift() - 50.0 * Wave.Height), "磁力波终点随车身升空")
	for i in 410: vehicle._physics_process(1.0 / 60.0)
	check(vehicle._visual_lift() >= Pull.HEIGHT - 0.01 and vehicle.global_position.distance_to(gun.global_position) < ground_pos.distance_to(gun.global_position) - 10.0, "升空后在空中向炮手拉近")
	var codec = preload("res://scripts/save/battle_snapshot.gd").new()
	var snap: Dictionary = codec.capture(world)
	var saved: Dictionary = codec.decode(codec.records[codec.ids[vehicle]].fields.special)
	check(BattleSaves.validate(snap).is_empty() and saved.get("magnet_source") == gun and is_equal_approx(float(saved[Pull.KEY].height), Pull.HEIGHT), "快照保留悬空高度与牵引来源")
	gun.attack_target = null
	vehicle._physics_process(1.0 / 60.0)
	check(vehicle.is_air_target() and not vehicle.special.has("magnet_source"), "停火后开始下落，不瞬移回地面")
	for i in 150: vehicle._physics_process(1.0 / 60.0)
	check(not vehicle.is_air_target() and vehicle.collision_layer == layer and not vehicle.special.has(Pull.KEY), "落地恢复地面碰撞与控制")
	var other: Unit = world.spawn_unit("MTNK", "enemy", gun.global_position + Vector2(140, 60))
	gun.attack_target = other
	gun._fire_shot(other, true)
	for i in 30: other._physics_process(1.0 / 60.0)
	var before_drop := other._visual_lift()
	gun.hp = 0.0
	other._physics_process(1.0 / 60.0)
	check(before_drop > 0.0 and other._visual_lift() < before_drop and not other.special.has("magnet_source"), "牵引者阵亡同样松手下落")
	for i in 120: other._physics_process(1.0 / 60.0)
	check(other.hp > 0.0 and not other.special.has(Pull.KEY), "牵引者阵亡后车辆能安全落地")
	if wave is Wave:
		vehicle.hp = 0.0
		wave._process(0.0)
	check(wave is Wave and wave.is_queued_for_deletion() and not wave.visible, "目标阵亡立刻清除波面")
	check(Wave.handles(gun, {"name": "MagneticBeamE"}) and not Wave.handles(vehicle, {"name": "MagneticBeam"}), "识别精英武器名，不接管其他单位")
	world.paused = true
	print("磁电坦克回归：%d/%d 通过" % [checks - failed, checks])
	tree.quit(int(failed > 0))
