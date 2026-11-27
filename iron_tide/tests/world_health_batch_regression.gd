extends Node

const Batch = preload("res://scripts/ui/world_health_bars.gd")
var failures := 0
var checks := 0

class Original extends "res://scripts/ui/world_health_bars.gd":
	func append(rect: Rect2, frac: float, fill: Color, ghost: float, rim: Color) -> bool:
		if used >= multimesh.instance_count: return false
		var size := rect.size + Vector2(4,4)
		multimesh.set_instance_transform_2d(used, Transform2D(Vector2(size.x,0), Vector2(0,size.y), rect.get_center()))
		multimesh.set_instance_color(used,fill)
		var state := Color(rect.size.x,rect.size.y,clampf(frac,0,1),clampf(ghost,clampf(frac,0,1),1)+(2.0 if rim.a>0 else 0.0))
		multimesh.set_instance_custom_data(used,state)
		used += 1
		return true

	func finish() -> void:
		multimesh.visible_instance_count = used

class Reference extends Original:
	var expected: Dictionary = {}

	func append(rect: Rect2, frac: float, fill: Color, ghost: float, rim: Color) -> bool:
		var index := used
		if not super.append(rect,frac,fill,ghost,rim): return false
		expected[index] = [rect,fill,Color(rect.size.x,rect.size.y,clampf(frac,0,1),clampf(ghost,clampf(frac,0,1),1)+(2.0 if rim.a>0 else 0.0))]
		return true

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)

func frame(batch: MultiMeshInstance2D, n: int, t: int, moving: int, offset: int = 0) -> int:
	batch.begin()
	var accepted := 0
	for i in n:
		var j := (i + offset) % n
		var p := float(t) * 0.35 if i < moving else 0.0
		var rect := Rect2(j*17.25+p, j%4*8.5, 32+j%6, 5+j%3)
		var hp := (t%10)*0.125-0.125 if j%17==0 else 0.7
		var ghost := (t%7)*0.2 if j%11==0 else hp
		var color := Color(0.25,0.625,0.75) if (j+t/8)%4 == 0 else Color(0.875,0.25,0.375)
		accepted += int(batch.append(rect,hp,color,ghost,Color.WHITE if j%3==0 else Color.TRANSPARENT))
	batch.finish()
	return accepted

func _ready() -> void:
	var a := Reference.new()
	var b := Batch.new()
	add_child(a)
	add_child(b)
	await get_tree().process_frame
	# The headless dummy renderer does not retain instance fields. Compare the
	# optimized slot state with the original append's actual submission inputs.
	for t in 48:
		var n: int = [0,1,128,256,263,31,3,128][t%8]
		Iso.MIRROR = t%2==1
		var size_a := frame(a,n,t,n/2,t%9)
		var size_b := frame(b,n,t,n/2,t%9)
		check(size_a==mini(n,256) and size_b==size_a and b.multimesh.visible_instance_count==a.multimesh.visible_instance_count,"capacity and visible count %d"%t)
		check(a.transform==b.transform,"projection %d"%t)
		for i in size_a:
			check(a.expected[i][0]==b._rects[i],"rect %d/%d"%[t,i])
			check(a.expected[i][1]==b._fills[i],"color %d/%d"%[t,i])
			check(a.expected[i][2]==b._states[i],"state %d/%d"%[t,i])
	for t in 6:
		frame(b,128,0,0)
		check(b._written==256 and b.multimesh.visible_instance_count==128,"repeated frame %d"%t)
	Iso.MIRROR = false
	if "--bench" in OS.get_cmdline_user_args() and failures == 0:
		var baseline := Original.new()
		add_child(baseline)
		for profile in [0,64,128,-1]:
			var row: Array[int] = []
			for batch in [baseline,b,b,baseline]:
				frame(batch,128,0,0)
				var t0 := Time.get_ticks_usec()
				for t in 1800:
					frame(batch,128,t,maxi(0,profile),t%128 if profile<0 else 0)
				row.append(Time.get_ticks_usec()-t0)
			print("ABBA us/1800 frames, 128 bars, moving=",profile," (-1 reorder): ",row)
		baseline.free()
	a.hide()
	b.hide()
	await battle_regression()
	print("world health batch: %d checks, %d failures"%[checks,failures])
	get_tree().quit(0 if failures==0 else 1)

func battle_regression() -> void:
	BattleRequest.configure_skirmish(MatchRules.EXTENDED, {"map_size":2400,"starting_funds":8000,"enemy_base":"allied"})
	var screen := preload("res://scenes/battle.tscn").instantiate()
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(screen)
	var battle: Battle = screen.battle
	battle.show_all_health = true
	await get_tree().process_frame
	battle.camera.force_update_scroll()
	var viewport := battle.get_viewport()
	var center := viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect().get_center()
	var actor: Unit = battle.spawn_unit("E1","ally",center)
	check(is_instance_valid(actor),"real battle spawns E1")
	if not is_instance_valid(actor): return
	actor.hp = actor.max_hp * 0.75
	actor._hp_ghost = 0.9
	actor._hp_flash = 0.0
	battle.hp_overlay.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	check(has_actor_bar(battle, actor, 0.75, 0.9),"real overlay submits HP and ghost")
	actor.position += Vector2(9,5)
	actor.hp = actor.max_hp * 0.125
	actor._hp_ghost = 0.5
	battle.hp_overlay.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	check(has_actor_bar(battle, actor, 0.125, 0.5),"real overlay submits new position and HP together")
	actor._hp_flash = 1.0
	battle.hp_overlay.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not has_actor_bar(battle, actor, 0.125, 0.5),"hit flash bypasses batch")
	actor._hp_flash = 0.0
	battle.hp_overlay.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	check(has_actor_bar(battle, actor, 0.125, 0.5),"actor returns to batch after flash")

func has_actor_bar(battle: Battle, actor: Unit, hp: float, ghost: float) -> bool:
	if not is_instance_valid(battle._health_batch): return false
	var bar := actor.hp_bar_rect()
	bar.position += Iso.dir(actor.presentation_position())
	var batch = battle._health_batch
	for i in batch.multimesh.visible_instance_count:
		if batch._rects[i] != bar: continue
		var data: Color = batch._states[i]
		if is_equal_approx(data.b,hp) and is_equal_approx(data.a,ghost): return true
	return false
