extends Node

func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	var ok: bool = MetaProgress.technology_owned("structure_queue") and MetaProgress.technology_owned("refinery_miner") and MetaProgress.balance("cores") == 0.0 and MetaProgress.stats.get("legacy_marker") == 17
	BattleRequest.configure_skirmish(MatchRules.EXTENDED, {})
	BattleRequest.freeze_combat_context()
	ok = ok and BattleRequest.combat_context.technologies.size() == 6 and MetaProgress.technology_owned("repair_all") and BattleRequest.has_unit_talent("R3REAPER","reaper_fire_control","ally") and MetaProgress.technology_owned("bunker_optics_3")
	BattleRequest.configure_skirmish(MatchRules.RA2, {})
	BattleRequest.freeze_combat_context()
	ok = ok and BattleRequest.combat_context.technologies.is_empty()
	print("TECHNOLOGY_COLD passed=", ok)
	get_tree().quit(0 if ok else 1)
