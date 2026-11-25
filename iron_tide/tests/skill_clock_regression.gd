extends "res://tests/electric_cards_regression.gd"

func exercise(mode:String) -> void:
	start(mode);battle.fog=null
	equip("SHK",Cards.PULSE,"",3)
	var unit=make("SHK","ally",Vector2(1200,1200))
	battle.selected_units=[unit]
	screen.hud._rebuild_ability_bar()
	var button:Button=screen.hud._ability_btns[1]
	var clock=button.get_node("CooldownClock")
	check(clock.mouse_filter==Control.MOUSE_FILTER_IGNORE,"clock does not block mouse input")
	if mode==MatchRules.RA2:
		check(not clock.visible,"empty classic W has no clock")
	else:
		var ab:Ability=unit.skills[UnitSkillLayout.index(unit,1)]
		var total:float=ab.cooldown/maxf(0.6,Unit.Training.card_scale(unit))
		for p in [0.0,0.25,0.5,0.75]:
			ab.cd_left=total*(1-p)
			screen.hud._update_ability_live()
			check(clock.visible and is_equal_approx(clock.progress,p),"actual skill clock progress "+str(p))
			check(is_equal_approx(clock.sweep_angle(),-PI/2+TAU*p),"clockwise noon/right/bottom/left "+str(p))
			check(button.disabled and button.get_meta("cd").text.ends_with("s"),"seconds and cooldown lock remain")
		ab.cd_left=0
		screen.hud._update_ability_live()
		check(not clock.visible and not button.disabled,"ready restores icon and clicking")
		unit._stun_timer=3
		screen.hud._update_ability_live()
		check(not clock.visible,"stun without cooldown does not invent a timer")
		var copy:Dictionary=BattleSaves.Snapshot.new().capture(battle)
		BattleSaves.Snapshot.new().restore(battle,copy)
		battle.paused=false;get_tree().paused=false
		unit=battle.units.filter(func(u):return u.unit_id=="SHK")[0]
		unit._stun_timer=0;ab=unit.skills[UnitSkillLayout.index(unit,1)];ab.cd_left=total*0.3
		battle.selected_units=[unit];screen.hud._rebuild_ability_bar()
		clock=screen.hud._ability_btns[1].get_node("CooldownClock")
		check(is_equal_approx(clock.progress,0.7),"rebuilt selection reads saved cooldown instead of restarting")
		# Building uses the same visual component in its icon region.
		equip("TESLA",Cards.PULSE,"",0)
		var coil=battle._place_building("TESLA","ally",Vector2(1600,1200),true)
		coil._buildup_play=-1;coil.powered=false
		battle.selected_building=coil;screen.hud._rebuild_ability_bar()
		check(screen.hud.TeslaPulse.use(coil),"building cooldown starts")
		coil.special.tesla_pulse.left=13.0;screen.hud._update_ability_live()
		clock=screen.hud._tesla_pulse_btn.get_node("CooldownClock")
		check(clock.visible and clock.progress==0.5,"building uses matching half-circle")
		coil.special.tesla_pulse.left=0;coil.under_construction=true;screen.hud._update_ability_live()
		check(not clock.visible and screen.hud._tesla_pulse_btn.disabled,"unavailable building with no cooldown hides clock")
	await finish()
