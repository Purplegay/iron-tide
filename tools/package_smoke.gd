extends Node
const Native = preload("res://scripts/world/native_maps.gd")
var checks: Array=[]
var failed := 0
var exports: Array=[]

func check(ok: bool, name: String) -> void:
	checks.append({"name":name,"passed":ok})
	if not ok: failed+=1;print("FAIL ",name)

func _ready() -> void:
	if DisplayServer.get_name()!="headless" or OS.get_environment("IRON_OUT").is_empty() or not OS.get_user_data_dir().contains("profile"):
		get_tree().quit(2);return
	get_tree().current_scene=null
	run.call_deferred()

func verify_export(path: String) -> void:
	var report=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(report is Dictionary and report.get("summary",{}).get("export_complete",false),"packaged battle exports JSON")
	if not report is Dictionary:return
	check(float(report.summary.get("session_sim_s",0.0))>0.0,"packaged battle advances simulation")
	var measured := false
	for row in report.summary.functions:
		if row.name=="fog.expire_held": measured=row.has("iterations") and row.calls>0
	check(measured,"packaged JSON contains fog calls and iteration counters")
	var bridge_recorded := false
	for window in report.get("windows",[]):
		var traffic:Dictionary=window.get("bridge_traffic",{})
		if traffic.has("bridges") and traffic.has("detail_policy") and traffic.get("sample_budget_per_frame")==16:
			bridge_recorded = true
	check(bridge_recorded,"packaged JSON contains bounded bridge diagnostics")
	exports.append(path)

func verify_battle_assets() -> void:
	var documents := ["ra2_allied.json"]
	for name in ["warheads", "general", "economy", "units", "buildings", "factions", "weapons", "projectiles", "animations", "sound_specs", "sfx_index", "eva_specs", "eva_index"]:
		documents.append("ra2/%s.json" % name)
	for document in documents:
		check(not GameData.raw_docs.get(document, {}).is_empty(), "rules loaded from package: " + document)
	check(not GameData.get_unit("E1").is_empty(), "GI definition available")
	for id in ["GACNST", "GAPILE", "GAPILL", "GAPOWR", "GAREFN", "GAWEAP"]:
		check(not GameData.get_building(id).is_empty(), "building definition available: " + id)
	var images := ["cursors/mouse", "ui/top-0", "ui/soviet/top-0"]
	for kind in ["ore", "gems"]:
		for variant in range(1, 4):
			images.append("resources/%s-%d" % [kind, variant])
	for image in images:
		var path := "res://assets/ra2/%s.png" % image
		check(ResourceLoader.exists(path) and load(path) is Texture2D, "battle texture available: " + path)

func run() -> void:
	verify_battle_assets()
	check(not OS.has_feature("editor"),"running actual exported release executable")
	check(ProjectSettings.get_setting("application/config/version")==OS.get_environment("IRON_PACKAGE_VERSION"),"package version")
	for path in ["res://assets/music/rock-and-awe.mp3","res://assets/ra2/fx/CRIVEXP.png"]:
		check(ResourceLoader.exists(path) and load(path)!=null,"packaged media "+path)
	var index := 0
	for id: String in Native.IDS:
		var country := "美国" if index%2==0 else "苏俄"
		BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"map_layout":id,"country":country,"enemy_country":"苏俄" if country=="美国" else "美国","fog_of_war":true,"difficulty":5})
		var screen=load("res://scenes/battle.tscn").instantiate()
		add_child(screen)
		for i in 30:await get_tree().physics_frame
		var world=screen.battle
		check(world!=null and world.fog!=null and world.skirmish_ai!=null,"native map opens "+id)
		check(world.map_layout()==id and world.map_size==Native.size_for(id),"native map data "+id)
		# Logic cadence is the fixed contract; the catch-up cap rose 2 -> 64 on 2026-11-18
		# (battle_frame_pacing.gd), so assert the cadence and that a cap still exists.
		check(Engine.physics_ticks_per_second==15 and Engine.max_physics_steps_per_frame>=2,"packaged fixed logic cadence")
		var path: String=screen.call_log.base_path+".json"
		screen.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
		verify_export(path)
		index+=1
	# Load only a copied fixture into this isolated profile, never a player slot.
	DirAccess.make_dir_recursive_absolute(BattleSaves.DIRECTORY)
	check(DirAccess.copy_absolute(OS.get_environment("IRON_SAVE"),ProjectSettings.globalize_path(BattleSaves.slot_path("slot1")))==OK,"copy checkpoint into isolated profile")
	var loaded: Dictionary=BattleSaves.load_into_scene("slot1")
	check(loaded.ok,"packaged build accepts the measured checkpoint")
	if loaded.ok:
		while get_tree().current_scene==null:await get_tree().process_frame
		var screen=get_tree().current_scene
		check(screen.battle.units.size()>=300 and screen.battle.buildings.size()>=190,"large checkpoint population restored")
		BattleClock.set_speed(1.0)
		get_tree().paused=false
		screen.battle.paused=false
		for i in 30:await get_tree().physics_frame
		var path: String=screen.call_log.base_path+".json"
		screen.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
		verify_export(path)
	FileAccess.open(OS.get_environment("IRON_OUT").path_join("smoke.json"),FileAccess.WRITE).store_string(JSON.stringify({"failed":failed,"checks":checks,"exports":exports,"visual_acceptance":"not measured headless"},"  "))
	print("PACKAGE_SMOKE_DONE ",failed)
	get_tree().quit(0 if failed==0 else 1)
