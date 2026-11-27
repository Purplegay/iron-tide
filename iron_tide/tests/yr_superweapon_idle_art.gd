extends Node

var checks := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed += 1
	print(("通过：" if ok else "失败：") + label)

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	BattleRequest.configure_skirmish(MatchRules.RA2, {"map_size": 3200, "starting_funds": 8000, "enemy_base": "yuri"})
	var screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	var world: Battle = screen.battle
	world.paused = true
	var index := 0
	for id in ["YAPPET", "YAGNTC"]:
		var actor: Building = world._place_building(id, "enemy", Vector2(1550 + index * 300, 1600), true)
		index += 1
		check(actor != null and actor._ra2.get("tex") != null, id + " 从战场实例化并加载主体")
		if actor == null: continue
		for hp_ratio in [1.0, 0.4, 1.0]:
			actor.hp = actor.max_hp * hp_ratio
			var damaged: bool = hp_ratio < 0.5
			var idle := {} as Dictionary
			var lights := {} as Dictionary
			for layer: Dictionary in actor._ra2_anim:
				if not actor._layer_visible(layer.kind): continue
				if layer.kind == "idleanim": idle = layer
				if layer.kind == "activeanim": lights = layer
			var label: String = "%s %.0f%% 血量 " % [id, hp_ratio * 100]
			check(not idle.is_empty(), label + "关盖层可见")
			if not idle.is_empty():
				var frames := sampled_frames(actor, idle)
				check(frames == ([1] if damaged else [0]), label + "十秒采样始终只用同一关盖帧 " + str(frames))
				check(uses_paired_shadows(actor, idle), label + "前景和原版投影分别取帧")
			if id == "YAPPET":
				check(not lights.is_empty(), label + "灯光层保留")
				if not lights.is_empty():
					var frames := sampled_frames(actor, lights)
					check(frames == ([6, 7, 8, 9] if damaged else [0, 1, 2, 3, 4]), label + "灯光只循环同一血量段 " + str(frames))
					check(uses_paired_shadows(actor, lights), label + "灯光未把影子区当成前景")
			actor.queue_redraw()
			await get_tree().process_frame
		verify_lid_cycle(world, actor)
	# Mute and exit only after the live scene has been freed.
	screen.queue_free()
	await get_tree().process_frame
	print("YURI_SUPERWEAPON_IDLE %d/%d" % [checks - failed, checks])
	get_tree().quit(1 if failed else 0)

func verify_lid_cycle(world: Battle, actor: Building) -> void:
	var id := actor.building_id
	var charge := actor.sw_recharge()
	check(actor._charged_anim_lead() == 60.0 and charge > 60.0, id + " 原版提前量一分钟")
	for ratio in [1.0, 0.4]:
		actor.hp = actor.max_hp * ratio
		var label := "%s %.0f%%" % [id, ratio * 100.0]
		actor._sw_charge = charge - 60.01
		check(selected_lid(actor).get("kind") == "idleanim", label + " 提前量之前关盖")
		verify_idle_composition(actor, label)
		actor._sw_charge = charge - 60.0
		var opening := selected_lid(actor)
		check(opening.get("kind") == "superanimtwo", label + " 剩余一分钟时开盖")
		if opening.get("kind") != "superanimtwo": continue
		var pose := actor._anim_layer(opening)
		check(actor._anim_frame_for(opening, pose) == pose.loopStart, label + " 开盖从第一帧起播")
		check(actor._uses_full_superweapon_pose() and body_layer_count(actor) == 0, label + " 开盖完整帧不叠画待机底座")
		actor._sw_charge += 1.0
		check(actor._anim_frame_for(opening, pose) > pose.loopStart and uses_paired_shadows(actor, opening), label + " 开盖逐帧推进且投影配对")
		actor._sw_charge = charge - 45.0
		var open := selected_lid(actor)
		check(open.get("kind") == "superanimthree", label + " 未充满即停在开盖待发动画")
		if open.get("kind") == "superanimthree":
			check(uses_paired_shadows(actor, open) and sampled_frames(actor, open).size() > 1, label + " 待发特效循环且投影配对")
			check(body_layer_count(actor) == 0, label + " 待发完整帧不叠画待机底座")
			var art := RA2Art.art(actor._anim_layer(open).image)
			var detail: Dictionary = art.get("detail", {})
			var detail_reader = preload("res://scripts/core/shp_detail.gd")
			var pages_ok := not detail.is_empty()
			for page in detail.get("pages", []):
				pages_ok = pages_ok and detail_reader.page_texture(page) != null
			check(pages_ok, label + " 战场待发帧的双倍贴图可加载")
	actor.hp = actor.max_hp
	actor._sw_charge = charge
	actor.powered = false
	var point := Vector2(2300, 1800)
	if world.fog != null: world.fog._reveal(actor.side, point, 330.0, 2.0)
	check(actor.fire_superweapon(point), id + " 通过正式发射入口")
	var closing := selected_lid(actor)
	check(closing.get("kind") == "superanimfour" and actor._sw_charge == 0.0, id + " 发射后播放关盖并重置倒计时")
	if closing.get("kind") == "superanimfour":
		check(uses_paired_shadows(actor, closing), id + " 关盖投影配对")
		check(body_layer_count(actor) == 0, id + " 收盖完整帧不叠画待机底座")
	actor._tick_superweapon(actor.sw_anim_seconds("superanimfour") + 0.1)
	check(selected_lid(actor).get("kind") == "idleanim", id + " 关盖结束后返回待机")
	verify_idle_composition(actor, id + " 发射结束")

func body_layer_count(actor: Building) -> int:
	var prefix := actor.building_id
	return actor.fog_pose().filter(func(layer):
		var file := str(layer[0]).get_file().get_basename()
		return file == prefix or (file.begins_with(prefix + "_") and file.trim_prefix(prefix + "_").is_valid_int())).size()

func verify_idle_composition(actor: Building, label: String) -> void:
	var mutator := actor.building_id == "YAGNTC"
	check(actor._uses_full_superweapon_pose() != mutator and body_layer_count(actor) == (1 if mutator else 0), label + " 待机按素材区分是否绘制主体底座")
	if not mutator: return
	var pose := actor.fog_pose()
	var lid := pose.filter(func(layer): return str(layer[0]).get_file().begins_with("YAGNTC_E"))
	check(lid.size() == 2 and pose.size() == 3, label + " 待机同时绘制底座、盖子及原版投影")
	if lid.size() != 2: return
	var foreground: Array = lid[1]
	var tex := load(foreground[0]) as Texture2D
	var used := tex.get_image().get_region(Rect2i(foreground[2]))
	var body := pose[0][1] as Rect2
	var lid_rect := foreground[1] as Rect2
	var lid_hit := false
	for y in range(used.get_height()):
		for x in range(used.get_width()):
			if used.get_pixel(x, y).a < 0.5: continue
			var local := lid_rect.position + (Vector2(x, y) + Vector2(0.5, 0.5)) / Vector2(used.get_size()) * lid_rect.size
			if body.has_point(local): continue
			lid_hit = actor.hit_test(actor.global_position + RA2Art.art_dir(local))
			if lid_hit: break
		if lid_hit: break
	check(lid_hit, label + " 点击能命中高于主体的盖子像素")

func selected_lid(actor: Building) -> Dictionary:
	var visible: Array = actor._ra2_anim.filter(func(layer):
		return (layer.kind == "idleanim" or str(layer.kind).begins_with("superanim")) and actor._layer_visible(layer.kind))
	return visible[0] if visible.size() == 1 else {}

func sampled_frames(actor: Building, layer: Dictionary) -> Array:
	var state := actor._anim_layer(layer)
	var unique := {}
	for sample in range(600):
		actor._anim_t = float(sample) / 60.0
		unique[actor._anim_frame_for(layer, state)] = true
	var result := unique.keys()
	result.sort()
	return result

func uses_paired_shadows(actor: Building, layer: Dictionary) -> bool:
	var state := actor._anim_layer(layer)
	var art := RA2Art.art(state.image)
	return art.get("tex") != null and state.shadow and state.frames * 2 == int(art.count) \
		and state.loopEnd < state.frames and RA2Art.src_rect(art, state.loopStart + state.frames).has_area()
