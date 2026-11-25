extends "res://tests/special_mechanics_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		arena(mode)
		await exercise()
		await finish()
	var report := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	report.close()
	get_tree().quit(0 if failed==0 else 1)

func exercise() -> void:
	if battle.fog != null:
		battle.fog.free()
		battle.fog=null
	var hud = battle.hud
	hud.process_mode=Node.PROCESS_MODE_ALWAYS
	hud.set_process(false)
	var bar = hud._sw_sidebar
	bar.refresh()
	check(not bar.visible,prefix+"empty roster hides sidebar")
	var sources := []
	for id in ["GACSPH","GAWEAT","NARADR","NAIRON","NAMISL","GATECH"]:
		var source = add(id,"ally",Vector2(300+sources.size()*270,800))
		sources.append(source)
	var enemy = add("NAMISL","enemy",Vector2(2000,400))
	var second = add("NAMISL","ally",Vector2(1500,400))
	second.under_construction=true
	battle.power_low=false
	bar.refresh()
	check(bar.buttons.size()==6 and not bar.buttons.has(enemy.get_instance_id()) and not bar.buttons.has(second.get_instance_id()),prefix+"only completed allied launchers")
	var textures := {}
	for source in sources:
		var button: Button = bar.buttons[source.get_instance_id()]
		check(button.icon!=null and button.icon.get_size()==Vector2(60,48) and button.disabled,prefix+source.sw_type()+" native icon and charging state")
		if button.icon!=null: textures[button.icon.resource_path]=true
		check(button.get_node("Charge").visible and button.get_node("Charge").value==1.0,prefix+"uncharged tile starts covered")
		source._sw_charge=source.sw_recharge()
	check(sources[5].sw_type() == "ForceShield" and bar.buttons[sources[5].get_instance_id()].icon != null, prefix+"Allied lab exposes charged Force Shield portrait")
	var sounds := Ra2Sfx.a_plays
	Ra2Sfx.stop_eva()
	var voices := Ra2Sfx.a_eva_plays
	sources[2]._tick_superweapon(0.0)
	sources[5]._tick_superweapon(0.0)
	check(Ra2Sfx.a_plays==sounds+1,prefix+"ready spy plane and shield share one global cue")
	var speech := Ra2Sfx._eva_player.stream
	check(Ra2Sfx.a_eva_plays==voices+1 and speech!=null and speech.resource_path.ends_with("/irontide_support_ready.wav") and speech.get_length()>1.0 and Ra2Sfx._eva_queue.is_empty(),prefix+"simultaneous support plays the English recording once")
	for index in [0,1,3,4]:
		var source = sources[index]
		source._tick_superweapon(0.0)
		var event: String = Ra2Sfx.SUPPORT_READY_VOICES[source.sw_type()]
		check(Ra2Sfx._eva_last.has(event.to_upper()),prefix+source.sw_type()+" requests its ready voice")
	var announced := Ra2Sfx.a_eva_plays + Ra2Sfx.a_eva_queued
	enemy._sw_charge=enemy.sw_recharge()
	enemy._tick_superweapon(0.0)
	for source in sources: source._tick_superweapon(0.0)
	bar.refresh()
	check(Ra2Sfx.a_plays==sounds+1 and Ra2Sfx.a_eva_plays+Ra2Sfx.a_eva_queued==announced,prefix+"ready launchers, HUD refresh and enemy charge stay silent")
	check(textures.size()==6,prefix+"six different weapon portraits")
	second.under_construction=false
	second._sw_charge=0
	battle.select_unit(spawn("MTNK","ally",Vector2(1250,1350)),false)
	var tank=battle.selected_units[0]
	battle._emit_selection()
	bar.refresh()
	hud._layout_selection_strip()
	var mask=bar.buttons[second.get_instance_id()].get_node("Charge")
	second._sw_charge=second.sw_recharge()*0.5
	bar.refresh()
	check(mask.fill_mode==ProgressBar.FILL_BOTTOM_TO_TOP and mask.value==0.5 and not bar.buttons[sources[0].get_instance_id()].get_node("Charge").visible,prefix+"half-charged launcher covered from the bottom while ready launcher is clear")
	for i in 4: await get_tree().process_frame
	check(bar.buttons.size()==7 and bar.buttons[second.get_instance_id()].disabled,prefix+"duplicate launcher retains its own charge")
	var origin: Vector2 = bar.position
	var narrow: float = bar.get_theme_stylebox("panel").get_minimum_size().x + 4 * bar.WIDTH + 3 * bar.grid.get_theme_constant("h_separation")
	bar.arrange(origin, narrow)
	for i in 3: await get_tree().process_frame
	var fifth: Button = bar.grid.get_child(4)
	var first: Button = bar.grid.get_child(0)
	check(fifth.position.x == first.position.x and fifth.position.y >= first.position.y + first.size.y and bar.size.x <= narrow, prefix+"seven compact tiles wrap after four")
	hud._layout_selection_strip()
	for i in 3: await get_tree().process_frame
	check(bar.get_global_rect().end.y <= hud.sel_strip.get_global_rect().position.y+1,prefix+"sidebar avoids unit portraits")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output_dir.path_join("left-support.png"))
	# Real GUI click, followed by two ordinary map confirmations, with a tank still selected.
	var tile: Button=bar.buttons[sources[0].get_instance_id()]
	var at:=tile.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new()
	motion.position=at
	get_viewport().push_input(motion,true)
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.position=at
		event.pressed=down
		get_viewport().push_input(event,true)
	check(battle._armed_superweapon==sources[0] and battle.selected_units==[tank],prefix+"left click arms without stealing selection")
	battle._issue_command_at(tank.position)
	check(battle._chrono_source_point.is_finite() and "目的地" in hud.cmd_hint_label.text and sources[0].sw_ready(),prefix+"first chrono click preserves charge")
	var goal:=Vector2(1700,1800)
	battle._issue_command_at(goal)
	check(tank.position==goal and not sources[0].sw_ready() and battle.selected_units==[tank],prefix+"second click teleports and spends only chrono")
	battle.clear_selection()
	for i in range(1,sources.size()):
		var source=sources[i]
		var item: Button=bar.buttons[source.get_instance_id()]
		item.pressed.emit()
		battle._emit_selection()
		check(battle.command_mode=="superweapon" and battle._armed_superweapon==source,prefix+source.sw_type()+" targets with empty selection")
		battle._issue_command_at(source.position if i==5 else tank.position)
		if i == 5: check(source.special.has("force_shield_left") and battle.allied_state.get("blackout_ally", 0) > 0, prefix+"Allied shield protects real building and drains base power")
		check(source._sw_charge==0 and battle.command_mode.is_empty(),prefix+source.sw_type()+" spends through actual weapon")
	battle.allied_state.erase("blackout_ally")
	battle.power_low=false
	second._sw_charge=second.sw_recharge()
	bar.refresh()
	bar.buttons[second.get_instance_id()].pressed.emit()
	battle.arm_command("")
	check(second.sw_ready(),prefix+"cancel costs no charge")
	bar.buttons[second.get_instance_id()].pressed.emit()
	AlliedAbilities.change_side(second,"enemy")
	battle._issue_command_at(tank.position)
	bar.refresh()
	check(not bar.buttons.has(second.get_instance_id()) and second._sw_charge==second.sw_recharge() and battle.command_mode.is_empty(),prefix+"capture during targeting removes access without firing")
	sources[1]._sw_charge=sources[1].sw_recharge()
	battle.power_low=true
	bar.refresh()
	check(bar.buttons[sources[1].get_instance_id()].disabled,prefix+"power loss disables charged weather controller")

	battle.power_low=false
	await check_spy_plane(sources[2])
	check_soviet_targeting(sources[3],sources[4])
	var soviet_lab = add("NATECH", "ally", Vector2(650, 1000))
	check(soviet_lab.sw_type() == "ForceShield", prefix+"Soviet lab retains its own shield")
	# Pre-fix slots persisted an empty ability on the Allied lab.
	var lab = sources[5]
	lab.superweapon = {}
	lab.data = lab.data.duplicate()
	lab.data.erase("superweapon")
	lab._sw_charge = 0
	BattleRequest.skirmish_config["fog_of_war"] = true
	var saved := BattleSaves.save_slot(battle, "quick")
	var loaded := BattleSaves.read_slot("quick")
	check(saved.ok and loaded.ok, prefix+"legacy lab slot validates", saved)
	if saved.ok and loaded.ok:
		BattleSaves.Snapshot.new().restore(battle, loaded.snapshot)
		battle.paused = false
		get_tree().paused = false
		var restored = battle.buildings.filter(func(b): return b.building_id == "GATECH")[0]
		bar.refresh()
		check(restored.sw_type() == "ForceShield" and restored._sw_charge == 0 and bar.buttons.has(restored.get_instance_id()), prefix+"legacy Allied lab regains uncharged shield and sidebar tile")

func check_spy_plane(radar) -> void:
	battle.fog=preload("res://scripts/world/fog_of_war.gd").new()
	battle.add_child(battle.fog)
	battle.fog.setup(battle)
	var site := Vector2(1000,2150)
	radar._sw_charge=radar.sw_recharge()
	battle.arm_superweapon(radar)
	var cursor = battle.command_cursor
	check(cursor.resolve(site)=="spy_plane" and cursor.textures.spy_plane.size()==8 and cursor.textures.spy_plane[7].region.position.x==385,prefix+"YR eight-frame spy cursor")
	battle.arm_command("")
	check(radar.sw_ready(),prefix+"cancel scout before confirming")
	battle.arm_superweapon(radar)
	check(not battle.fog.is_explored_at("ally",site),prefix+"unexplored reconnaissance site")
	battle._issue_command_at(site)
	var scouts:Array=battle.units.filter(func(u):return u.unit_id=="SPYP" and u.special.get("spy_point")==site)
	check(scouts.size()==1 and radar._sw_charge==0 and battle.command_mode=="",prefix+"one map click launches scout into shroud")
	if scouts.size()!=1:return
	var plane=scouts[0]
	plane._physics_process(0.01)
	var engine=plane.get_node_or_null("SpyEngine")
	check(is_instance_valid(engine) and engine.playing and engine.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,prefix+"aircraft owns an audible positional flyby loop")
	var first:Vector2=plane.special.spy_photo
	var flashes=battle.effects_root.get_children().filter(func(f): return f is Effects.Flash and not f.visual_offset.is_zero_approx() and f.position.distance_to(first)<1.0)
	if not flashes.is_empty(): battle.fog._filter_transient(flashes.back())
	check(not flashes.is_empty() and flashes.back().visible,prefix+"snapshot flash drawn at aircraft height and visible over its photographed ground")
	var picture_count:int=Ra2Sfx.a_plays
	plane._physics_process(0.5)
	check(plane.special.spy_photo==first and Ra2Sfx.a_plays==picture_count,prefix+"shutter respects native interval")
	plane._physics_process(0.6)
	check(plane.special.spy_photo!=first and Ra2Sfx.a_plays>picture_count and Ra2Sfx._pool.any(func(p):return p.playing and p.stream==Ra2Sfx._stream("yr_recon/vspysnap.wav")),prefix+"successive snapshots advance along route and play original sample")
	for i in 25:
		plane._physics_process(0.25)
		battle.fog.rebuild()
		if plane.position.distance_to(site)<150: break
	check(battle.fog.is_visible_at("ally",site+Vector2(0,180)),prefix+"camera footprint survives fog rebuild at overflight")
	plane._physics_process(100)
	battle.fog.rebuild()
	check(plane.is_queued_for_deletion() and battle.fog.is_explored_at("ally",site) and not battle.fog.is_visible_at("ally",site+Vector2(0,180)),prefix+"scout exits leaving terrain explored")
	await get_tree().process_frame
	check(not is_instance_valid(engine),prefix+"engine audio retires with aircraft")

func check_soviet_targeting(iron,silo) -> void:
	var point := Vector2(1100,1100)
	var outside := Vector2(-5,1100)
	var unknown := Vector2.INF
	for y in range(20,int(battle.map_size),40):
		for x in range(20,int(battle.map_size),40):
			var cell := Vector2(x,y)
			if cell.distance_to(point)>650 and not battle.fog.is_explored_at("ally",cell):
				unknown=cell
				break
		if unknown.is_finite(): break
	check(unknown.is_finite(),prefix+"fixture has unexplored terrain")
	if not unknown.is_finite(): return
	var cursor=battle.command_cursor
	var rules=preload("res://scripts/units/soviet_specials.gd")
	battle.power_low=false
	get_window().focus_entered.emit()
	for row in [[iron,"iron",77.0],[silo,"nuke",550.0]]:
		var source=row[0]
		source._sw_charge=source.sw_recharge()
		battle.arm_superweapon(source)
		var charge:float=source._sw_charge
		check(cursor.resolve(outside)=="blocked" and not rules.superweapon(source,outside),prefix+"off-map denied "+row[1])
		check(cursor.resolve(unknown)=="blocked",prefix+"unexplored target blocked "+row[1])
		battle._issue_command_at(unknown)
		check(battle.command_mode=="superweapon" and source._sw_charge==charge,prefix+"invalid click preserves charge and targeting")
		battle.fog._reveal("ally",point,610)
		battle.fog._sync_mask()
		check(cursor.resolve(point)==row[1] and is_equal_approx(rules.target_radius(source.sw_type()),row[2]),prefix+"native cursor and actual world radius "+row[1])
		battle.arm_command("")
		check(source.sw_ready() and battle._armed_superweapon==null and cursor.resolve(point)!=row[1],prefix+"cancel restores normal pointer without spending")
