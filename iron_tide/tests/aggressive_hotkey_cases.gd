extends RefCounted
const Keys=preload("res://scripts/ui/battle_hotkeys.gd")

static func press(t,key:int) -> void:
	var event:=InputEventKey.new();event.keycode=key;event.pressed=true
	t.screen.hud._input(event)

static func run(t,mode:String) -> void:
	t.open_arena(mode)
	# Earlier save/load cases can leave the shared SceneTree paused.
	t.get_tree().paused=false;t.battle.paused=false
	t.get_window().focus_entered.emit()
	Keys.save(Keys.defaults())
	var unit=t.battle.spawn_unit("MTNK","ally",Vector2(1200,1200))
	var peer=t.battle.spawn_unit("E1","ally",Vector2(1180,1200))
	var tower=t.battle._place_building("GAPOWR","enemy",Vector2(1300,1200),true)
	tower._buildup_play=-1
	t.battle.select_unit(unit,false);t.battle.select_unit(peer,true)
	unit.order_guard();peer.set_fire_stance("none")
	press(t,KEY_V)
	t.check(unit.fire_stance=="free" and peer.fire_stance=="free" and not unit.hold_position,"V unifies mixed selected stances and exits guard "+mode,{"input":t.battle.world_input_enabled(),"paused":t.get_tree().paused,"ended":t.battle.ended,"selected":t.battle.selected_units.size(),"key":Keys.bindings.aggressive,"unit":unit.fire_stance,"peer":peer.fire_stance,"alive":t.battle.actor_alive(unit)})
	t.check(unit.attack_target==tower and unit._weapon_target_valid(tower),"aggressive stance acquires enemy building through real targeting")
	press(t,KEY_V)
	t.check(unit.fire_stance=="defend" and peer.fire_stance=="defend","repeated V closes aggressive mode and restores automatic defense")
	unit.order_move(Vector2(1500,1500));var destination:Vector2=unit.move_target
	press(t,KEY_V)
	t.check(unit.has_move_order and unit.move_target==destination,"aggressive hotkey retains explicit movement")
	unit.order_target(tower,false,false);press(t,KEY_V)
	t.check(unit.attack_ordered and unit.attack_target==tower,"aggressive hotkey retains explicit attack")
	peer.set_deployed(true,false);press(t,KEY_V)
	t.check(peer.is_deployed(),"aggressive hotkey never changes deployed posture")
	press(t,KEY_S)
	t.check(unit.fire_stance=="defend" and peer.fire_stance=="defend","S restores automatic defense")
	t.battle.paused=true;press(t,KEY_V);t.battle.paused=false
	t.check(unit.fire_stance=="defend","paused battle rejects aggressive hotkey")
	Keys.modal_count=1;press(t,KEY_V);Keys.modal_count=0
	t.check(unit.fire_stance=="defend","hotkey editor modal blocks aggressive command")
	t.check(Keys.assign("aggressive",KEY_A).contains("冲突"),"aggressive rebinding rejects occupied attack key")
	t.check(Keys.assign("aggressive",KEY_B).is_empty(),"aggressive action supports custom key")
	Keys.loaded=false;Keys.ensure()
	press(t,KEY_V)
	t.check(unit.fire_stance=="defend" and Keys.bindings.aggressive==KEY_B,"custom hotkey persists and original V becomes inactive")
	press(t,KEY_B)
	t.check(unit.fire_stance=="free","rebound key reaches actual battle command")
	var button=t.screen.hud._unit_command_buttons.get("aggressive")
	t.check(button!=null and button.tooltip_text.contains("主动进攻"),"command menu exposes aggressive action")
	var legacy:=ConfigFile.new()
	for id in Keys.ACTIONS:
		if id not in ["aggressive","snapshot"]:legacy.set_value("keys",id,KEY_V if id=="attack" else Keys.ACTIONS[id][1])
	legacy.save(Keys.PATH);Keys.loaded=false;Keys.ensure()
	t.check(Keys.bindings.attack==KEY_V and Keys.bindings.aggressive!=KEY_V and Keys.bindings.snapshot!=Keys.bindings.aggressive,"legacy V binding survives migration without conflicts")
	Keys.save(Keys.defaults())
	t.battle.clear_selection();press(t,KEY_V)
	t.check(unit.fire_stance=="free","empty selection does not alter previous unit")
	await t.finish()
