extends Node
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	var out:=OS.get_environment("IRON_OUT")
	if out.is_empty() or not FileAccess.file_exists(OS.get_environment("IRON_SAVE")) or not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(BattleSaves.DIRECTORY)
	DirAccess.copy_absolute(OS.get_environment("IRON_SAVE"),ProjectSettings.globalize_path(BattleSaves.slot_path("slot1")))
	get_tree().current_scene=null
	seed(12345)
	var loaded:=BattleSaves.load_into_scene("slot1")
	if not loaded.ok:print(loaded);get_tree().quit(2);return
	while get_tree().current_scene==null:
		await get_tree().process_frame
	await get_tree().process_frame
	var screen=get_tree().current_scene
	var world=screen.battle
	world.paused=false;get_tree().paused=false
	BattleClock.set_speed(1)
	var began:=Time.get_ticks_usec()
	while Time.get_ticks_usec()-began<65000000:
		await get_tree().process_frame
	screen.call_log.close("test_exit")
	var path:String=screen.call_log.base_path
	var records=[]
	for line in FileAccess.get_file_as_string(path+".jsonl").split("\n",false):records.append(JSON.parse_string(line))
	var windows=records.filter(func(row):return row.kind=="window")
	var valid:bool=windows.size()==2 and records[-1].kind=="test_exit"
	for row in windows:
		valid=valid and row.window_wall_s>=30 and row.window_wall_s<32 and row.frames.count>0 and not row.functions.is_empty()
		valid=valid and row.functions.any(func(f):return f.name=="unit._physics_process" and f.calls>0 and f.timed_calls>0)
	var exported=JSON.parse_string(FileAccess.get_file_as_string(path+".json"))
	valid=valid and exported is Dictionary
	if exported is Dictionary:
		valid=valid and exported.header.match_id==world.match_id and exported.windows.size()==records.size()-1 and exported.summary.end_reason=="test_exit"
		valid=valid and exported.summary.session_sim_s>0 and exported.summary.effective_speed>0 and exported.summary.frames.count>0
		for function in exported.summary.functions:
			var expected:=0
			for row in records:
				for entry in row.get("functions",[]):
					if entry.name==function.name:expected+=int(entry.calls)
			valid=valid and int(function.calls)==expected
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":valid,"path":path,"windows":windows,"records":records.size(),"json_export":path+".json"},"  "))
	print("CALL_LOG_LIVE passed=",valid," windows=",windows.size()," path=",path)
	get_tree().quit(0 if valid else 1)
