extends "res://tests/skill_scope_regression.gd"
const Gallery=preload("res://scripts/ui/faction_card_gallery.gd")

func exercise(mode:String) -> void:
	await super.exercise(mode)
	if mode==MatchRules.RA2:return
	start(mode);battle.fog=null
	BattleRequest.combat_context.bonuses=MatchRules.neutral_bonuses();BattleRequest.combat_context.unit_bonus={}
	for rank in 4:
		var fraction:float=[0.2,0.25,0.3,0.35][rank]
		BattleRequest.combat_context.loadouts.E1={"active":["ap_focus_fire"],"passive":"ps_hollow_point"}
		BattleRequest.combat_context.card_ranks.ap_focus_fire=rank
		BattleRequest.combat_context.card_ranks.ps_hollow_point=rank
		BattleRequest.combat_context.get_or_add("card_strength_overrides",{}).ap_focus_fire=1.0+0.15*rank
		var soldier=make("E1","ally",Vector2(1200,1200));var target=make("E1","enemy",Vector2(1240,1200))
		soldier.attack_target=target;soldier.attack_ordered=true;soldier.hull_angle=0;soldier.turret_angle=0
		check(soldier._try_fire_ready(),"baseline infantry fires "+str(rank))
		var baseline:float=soldier._cd_timer
		var before:float=target.hp;soldier._fire_shot(target);var damage:float=before-target.hp
		var idx:int=UnitSkillLayout.index(soldier,1)
		check(soldier.use_ability(idx),"focus activates rank "+str(rank))
		check(is_equal_approx(soldier._cd_timer,baseline),"cast preserves pending reload "+str(rank))
		soldier._cd_timer=baseline*0.5
		check(is_equal_approx(preload("res://scripts/ui/attack_cooldown_indicator.gd").ordinary_slot(soldier,soldier.weapon,"hull").fraction,0.5),"casting does not jump existing reload ring "+str(rank))
		check(is_equal_approx(soldier.buff_value("cooldown"),fraction) and soldier.buff_value("attack")==0,"focus has reload buff only "+str(rank))
		soldier._cd_timer=0;soldier._burst_left=0
		check(soldier._try_fire_ready() and is_equal_approx(soldier._cd_timer,baseline*(1-fraction)),"actual next weapon reload shortened "+str(rank))
		before=target.hp;soldier._fire_shot(target)
		check(is_equal_approx(before-target.hp,damage),"focus leaves hollow point shot damage unchanged "+str(rank))
		check(soldier.passive.id=="ps_hollow_point" and soldier.bonuses.attack_bonus>1.0,"hollow point retains passive damage bonus "+str(rank))
		soldier._cd_timer=baseline*(1-fraction)*0.5;soldier._tick_buffs(6.1)
		check(is_equal_approx(preload("res://scripts/ui/attack_cooldown_indicator.gd").ordinary_slot(soldier,soldier.weapon,"hull").fraction,0.5),"expiry does not jump shortened reload ring "+str(rank))
		soldier._cd_timer=0;soldier._burst_left=0
		check(soldier._try_fire_ready() and is_equal_approx(soldier._cd_timer,baseline),"expiry restores normal reload "+str(rank))
		# Previously saved Ability objects retain cooldown but load the revised effect/curve.
		var ab:Ability=soldier.skills[idx];ab.setup({"id":"ap_focus_fire","effect":"attack_buff","value":0.5});ab.cd_left=7.0
		Cards.restore(soldier)
		check(ab.effect_has("cooldown_buff") and is_equal_approx(ab.value,fraction) and ab.cd_left==7.0,"old ability restore keeps cooldown and updates rule "+str(rank))
		clear_units()
	var gallery:=Gallery.new();add_child(gallery)
	for rank in 4:
		gallery.select_card(gallery.ids.find("ap_focus_fire"),rank)
		check(gallery.summary.text.contains("装填时间缩短") and gallery.summary.text.contains("单发伤害不变"),"focus description explains reload "+str(rank))
		check(gallery.stage.focus_shots(true).size()>gallery.stage.focus_shots(false).size(),"focus demo visibly fires more rounds "+str(rank))
		gallery.select_card(gallery.ids.find("ps_hollow_point"),rank)
		check(gallery.summary.text.contains("单发伤害") and gallery.summary.text.contains("装填时间不变"),"hollow description distinguishes single-hit damage "+str(rank))
	gallery.free()
	await finish()
