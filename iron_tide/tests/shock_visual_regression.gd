extends "res://tests/electric_cards_regression.gd"
const Shock=preload("res://scripts/core/shock_pulse.gd")

func exercise(mode:String) -> void:
	start(mode);battle.fog=null
	if mode==MatchRules.RA2:
		await finish();return
	var previous=[Iso.K,Iso.MIRROR,Iso.USE_YAW]
	for k in [0.35,0.5,0.71]:
		for mirror in [false,true]:
			for yaw in [false,true]:
				Iso.K=k;Iso.MIRROR=mirror;Iso.USE_YAW=yaw
				var points:=Iso.ground_circle(Vector2.ZERO,275)
				var cross:=0.0;var xx:=0.0;var yy:=0.0;var radial_error:=0.0
				for p in points:
					radial_error=maxf(radial_error,absf(p.length()-275))
					var screen:=Iso.dir(p)
					cross+=screen.x*screen.y;xx+=screen.x*screen.x;yy+=screen.y*screen.y
				check(radial_error<0.001 and absf(cross/xx)<0.0001 and absf(yy/xx-k*k)<0.0001,"ground circle projects once without diagonal shear")
	Iso.K=previous[0];Iso.MIRROR=previous[1];Iso.USE_YAW=previous[2]
	equip("SHK",Cards.PULSE,"",0)
	var actor=make("SHK","ally",Vector2(1200,1200))
	var target=make("HTNK","enemy",Vector2(1300,1200))
	battle.select_unit(actor,false)
	var slot:=UnitSkillLayout.find(actor,Cards.PULSE)
	battle.cast_slot=slot;battle.confirm_cast()
	var effects:=get_tree().get_nodes_in_group("shock_pulse_fx")
	check(effects.size()==1 and battle._cast_flashes.is_empty(),"actual aiming confirmation emits one dedicated wave without old generic flash")
	check(actor.ability_at(slot).cd_left==26 and target.hp<target.max_hp,"real cast still damages immediately and uses original cooldown")
	var fx=effects[0]
	fx._process(0.22)
	check(not fx.is_queued_for_deletion() and fx.wave_fraction()<1,"pulse remains visible beyond old lifetime")
	for time in [0.0,0.3,0.95,1.4,1.79]:
		fx.age=time
		for delay in [0.0,0.16,0.32]:check(fx.wave_fraction(delay)>=0 and fx.wave_fraction(delay)<=1,"wave never exceeds actual damage radius")
	fx.age=1.4
	check(fx.fade()>0 and fx.fade()<0.6,"long tail fades gradually")
	fx._process(0.41)
	check(fx.is_queued_for_deletion(),"visual lifetime is bounded")
	for i in 10:Shock.spawn(actor,275)
	var detailed:=0
	for effect in get_tree().get_nodes_in_group("shock_pulse_fx"):
		if effect.detail:detailed+=1
	check(detailed<=8,"simultaneous casts bound detail budget")
	await finish()
