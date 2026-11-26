extends Node2D
class_name BattleScreen
## 战斗场景根：装配战场、HUD 与结算界面。

const BattleScript := preload("res://scripts/world/battle.gd")
const HUDScript := preload("res://scripts/ui/hud.gd")
@onready var kit = UiKit

var battle
var hud
var result_overlay: Control = null
var overlay_layer: CanvasLayer
var call_log := preload("res://scripts/world/battle_call_log.gd").new()
var frame_pacing := preload("res://scripts/world/battle_frame_pacing.gd").new()
var expedition_runtime
var crash_trace := preload("res://scripts/world/battle_crash_trace.gd").new()

func _ready() -> void:
	Music.set_context("preparing")
	battle = BattleScript.new()
	add_child(crash_trace)
	crash_trace.start(battle)
	battle.frame_pacing = frame_pacing
	add_child(battle)

	hud = HUDScript.new()
	add_child(hud)

	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 20
	add_child(overlay_layer)

	# 先让 HUD 接上事件总线，再初始化战场，避免丢失开局提示消息
	hud.setup(battle)
	crash_trace.mark("setup.begin")
	battle.setup(BattleRequest.mission_id, hud)
	crash_trace.mark("setup.end", {"map": battle.map_layout()})
	var restored_expedition:=not BattleSaves.pending.is_empty()
	crash_trace.mark("restore.begin", {"pending": restored_expedition})
	BattleSaves.restore_pending(battle)
	crash_trace.mark("restore.end")
	preload("res://scripts/world/battle_music_director.gd").begin(battle, restored_expedition)
	var expedition_active := preload("res://scripts/expedition/rules.gd").active()
	if expedition_active:
		# 旧远征与中途检查点可能只记录了一级维修。
		if battle.can_repair_all() and MetaProgress.technology_active("repair_auto"):
			battle.production_technology.unlock("repair_auto", "ally")
	if not restored_expedition and DisplayPreferences.automatic_building_repair and battle.can_repair_all() and battle.production_technology.is_unlocked("repair_auto", "ally"):
		battle.allied_state.area_repair = 2
	if expedition_active:
		expedition_runtime=preload("res://scripts/expedition/runtime.gd").new()
		add_child(expedition_runtime)
		if not expedition_runtime.setup(battle,restored_expedition):
			battle.paused=true
			get_tree().paused=true
			Expedition.cancel_launch()
			_show_expedition_result({"win":false,"setup_error":expedition_runtime.error})
		else:
			hud.expedition_save_and_leave=expedition_runtime.save_and_leave
			hud.minimap.objectives=expedition_runtime.tasks
			expedition_runtime.install_hud(overlay_layer)
			if not restored_expedition and not Expedition.checkpoint(battle):expedition_runtime.show_error(Expedition.error)
	var autosave := preload("res://scripts/save/battle_autosave.gd").new()
	autosave.setup(battle, crash_trace)
	add_child(autosave)
	add_child(call_log)
	call_log.setup(battle)
	if battle.building_art_warmup != null:
		battle.building_art_warmup.prepare_existing_buildings(battle.buildings)
		battle.building_art_warmup.prepare_infantry(battle.units)
	hud.show_skirmish_difficulty()
	preload("res://scripts/world/combat_media_warmup.gd").install(battle)
	add_child(frame_pacing)
	hud.refresh_repair_all()
	Events.battle_ended.connect(_on_battle_ended)
	Events.wave_started.connect(_on_wave_started)
	crash_trace.mark("battle.ready")

func _on_wave_started(_index: int, _wave_name: String) -> void:
	# PathMusic director owns battle score transitions; waves do not reset it.
	if not battle.ended and Music.context != "battle":
		Music.set_context("battle", battle.roster_faction("ally"), true)

func _exit_tree() -> void:
	BattleClock.leave_battle()
	Ra2Sfx.stop_all()
	Music.set_context("menu")

func _on_battle_ended(result: Dictionary) -> void:
	if is_instance_valid(hud.expedition_panel):hud.expedition_panel.hide()
	call_log.close("battle_ended")
	battle.frame_pacing = null
	frame_pacing.queue_free()
	if not bool(result.get("win", false)) or bool(result.get("draw", false)):
		Music.set_context("results")
	get_tree().paused = false
	BattleClock.leave_battle()
	if result.get("win",false) and not result.get("draw",false):
		_show_victory_card(result)
	else:
		_show_result(result)

func _show_victory_card(result: Dictionary) -> void:
	var faction: String = battle.roster_faction("ally")
	Ra2Sfx.play_victory_eva(faction)
	var root := ColorRect.new()
	root.name = "VictoryAnnouncement"
	root.color = Color(0.025,0.035,0.05,0.82)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay_layer.add_child(root)
	result_overlay = root
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	center.add_child(column)
	var title := kit.make_label("战区胜利",32,kit.COL_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var poster := TextureRect.new()
	var poster_path := "res://assets/ra3/ui/victory/%s.png" % faction
	if ResourceLoader.exists(poster_path):
		poster.texture = load(poster_path)
	else:
		poster.hide()
	poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	poster.custom_minimum_size = Vector2(210, minf(304,get_viewport_rect().size.y*0.48))
	column.add_child(poster)
	var proceed := kit.make_button("查看结算",18)
	proceed.pressed.connect(_show_result.bind(result),CONNECT_ONE_SHOT)
	column.add_child(proceed)
	proceed.grab_focus()

func _show_result(result: Dictionary) -> void:
	if preload("res://scripts/expedition/rules.gd").active():
		_show_expedition_result(result)
		return
	if result_overlay != null and is_instance_valid(result_overlay):
		result_overlay.queue_free()
	var win := bool(result.get("win", false))
	var draw := bool(result.get("draw", false))
	var rewards: Dictionary = result.get("rewards", {})

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_layer.add_child(root)
	result_overlay = root

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var box := kit.make_panel(Color(0.08, 0.1, 0.14, 0.99), Color(0.45, 0.7, 1.0), 8, 2, 18)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(520, 0)
	root.add_child(box)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	box.add_child(vb)

	var title := kit.make_label("平  局" if draw else ("胜  利" if win else "败  北"), 34, kit.COL_OK if win else kit.COL_WARN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	for skin in result.get("cosmetic_rewards",[]):
		vb.add_child(kit.make_label("胜利解锁 · "+MetaProgress.Cosmetics.display_name(skin),16,kit.COL_GOLD))

	var mission := GameData.get_mission(str(result.get("mission", "")))
	var ra2 := str(result.get("rules_mode", MatchRules.EXTENDED)) == MatchRules.RA2
	vb.add_child(kit.make_label("规则：%s" % ("红警 2 经典规则" if ra2 else "Iron Tide 扩展"), 14, kit.COL_DIM))
	vb.add_child(kit.make_label("战区：%s" % mission.get("name", "遭遇战"), 14, kit.COL_DIM))
	vb.add_child(kit.divider())

	if (result.get("endless", false) == true):
		vb.add_child(kit.make_label("坚持轮数：%d" % int(result.get("loop", 0)), 15, kit.COL_TEXT))
	vb.add_child(kit.make_label("击杀：%d" % int(result.get("kills", 0)), 15, kit.COL_TEXT))
	vb.add_child(kit.make_label("通过波次：%d" % int(result.get("waves", 0)), 15, kit.COL_TEXT))
	vb.add_child(kit.divider())
	if draw:
		vb.add_child(kit.make_label("双方同时覆灭，本局不计入养成奖励。", 14, kit.COL_DIM))
	elif result.get("campaign_settlement",false):
		var heading := "本局已结算" if rewards.get("already_settled",false) else ("首胜奖励" if rewards.get("first_win",false) else "重打奖励")
		if rewards.is_empty(): heading = "本次未获得通关奖励"
		vb.add_child(kit.make_label(heading,18,kit.COL_ACCENT_2))
		for recruit in rewards.get("recruits",[]):
			vb.add_child(kit.make_label("中立英雄入册 · "+MetaProgress.Academy.HEROES[recruit],18,kit.COL_GOLD))
		if rewards.has("first_win"): preload("res://scripts/rules/campaign_payout.gd").reward_row(vb,"",rewards,18,kit.COL_GOLD)
	elif ra2 and not result.get("endless",false):
		vb.add_child(kit.make_label("经典规则对局不增加扩展模式的养成进度。", 14, kit.COL_DIM))
	else:
		vb.add_child(kit.make_label("本次结算奖励", 15, kit.COL_ACCENT_2))
		var adjustment: Dictionary = result.get("alliance_reward", {})
		if not adjustment.is_empty():
			vb.add_child(kit.make_label(BattleRequest.Houses.reward_description(adjustment), 14, kit.COL_DIM))
		vb.add_child(kit.make_label("军需券 +%d" % int(rewards.get("credits", 0)), 16, kit.COL_GOLD))
		vb.add_child(kit.make_label("战略核心 +%d" % int(rewards.get("cores", 0)), 16, kit.COL_ACCENT))
		vb.add_child(kit.divider())
		vb.add_child(kit.make_label("可用于驻防升级与解锁档位，永久生效。", 12, kit.COL_DIM))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	var again := kit.make_button("重新挑战", 15)
	again.pressed.connect(func():
		BattleClock.leave_battle()
		get_tree().reload_current_scene())
	row.add_child(again)
	var to_lobby := kit.make_button("选择关卡", 15)
	to_lobby.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/lobby.tscn" if BattleRequest.skirmish else "res://scenes/campaign_command.tscn"))
	row.add_child(to_lobby)
	var to_meta := kit.make_button("前往驻防", 15)
	to_meta.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/meta.tscn"))
	row.add_child(to_meta)
	var to_menu := kit.make_button("返回主菜单", 15)
	to_menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	row.add_child(to_menu)
	if win and result.get("mission")=="yr_head_games" and not battle.allied_state.has("head_postscore"):
		battle.allied_state.head_postscore=true
		preload("res://scripts/ui/hollywood_film.gd").show_clip(battle,"S08_F00E")

func _show_expedition_result(result:Dictionary) -> void:
	if is_instance_valid(result_overlay):result_overlay.queue_free()
	var root:=CenterContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.process_mode=Node.PROCESS_MODE_ALWAYS
	overlay_layer.add_child(root)
	result_overlay=root
	var box:=kit.make_panel(Color("#101923"),kit.COL_GOLD)
	box.custom_minimum_size=Vector2(550,220)
	root.add_child(box)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",18)
	box.add_child(column)
	var win:bool=result.get("win",false)
	var title:="远征完成 · 凶残 3 三连战已攻克" if win and Expedition.state.get("phase","")=="complete" else "战区胜利 · 领取补给" if win else "远征结束"
	if result.has("setup_error"):title="战区准备失败"
	column.add_child(kit.make_label(title,26,kit.COL_GOLD))
	column.add_child(kit.make_label(str(result.get("setup_error","当前远征进度已保存。")),14,kit.COL_TEXT))
	if not result.has("setup_error"):
		preload("res://scripts/expedition/keepsake_notice.gd").add_report_rows(column,Expedition.state.id,expedition_runtime.Rules.context().stage)
		var rewards:Dictionary=result.get("rewards",{})
		column.add_child(kit.make_label("常规收益：军需券 +%d · 战略核心 +%d"%[rewards.get("credits",0),rewards.get("cores",0)],16,kit.COL_GOLD))
		if win and not Expedition.state.get("history",[]).is_empty():
			var income=preload("res://scripts/expedition/income.gd")
			column.add_child(kit.make_label("远征额外"+income.history_text(Expedition.state,Expedition.state.history.back(),MetaProgress),16,kit.COL_GOLD))
	var next:=kit.make_button("返回远征营地",18)
	next.pressed.connect(_return_expedition)
	column.add_child(next)

func _return_expedition() -> void:
	get_tree().paused=false
	BattleClock.leave_battle()
	get_tree().change_scene_to_file("res://scenes/expedition.tscn")
