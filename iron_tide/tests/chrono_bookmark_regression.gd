extends "res://tests/ground_control_regression.gd"
const Talents = Unit.YRTalents
const Ring = preload("res://scripts/ui/attack_cooldown_indicator.gd")

func exercise(mode: String) -> void:
	start(mode)
	battle.fog = null
	BattleRequest.combat_context.bonuses = MatchRules.neutral_bonuses()
	BattleRequest.combat_context.unit_bonus = {}
	BattleRequest.combat_context.unit_talents = {}
	for rank in 4:
		BattleRequest.combat_context.unit_talents = {"CLEG":{Talents.BOOK:rank}}
		var actor = battle.spawn_unit("CLEG","ally",Vector2(1200,1200))
		var target = battle.spawn_unit("HTNK","enemy",Vector2(1240,1200))
		activate(actor)
		activate(target)
		actor._stun_timer = 0
		actor.bonuses = MatchRules.neutral_bonuses()
		target.hp = 400
		target.max_hp = target.hp
		actor.order_target(target,false,false)
		actor.aim_dir = Vector2.RIGHT
		actor.hull_angle = 0
		actor.turret_angle = 0
		actor._cd_timer = 0
		var reduction: float = (0.2+rank*0.1) if mode==MatchRules.EXTENDED else 0.0
		var interval: float = 8.0*(1.0-reduction)
		check(actor._try_fire_ready(),prefix+str(rank)+" actual firing begins channel")
		check(is_equal_approx(actor._cd_timer,interval),prefix+str(rank)+" reload uses talent rank",actor._cd_timer)
		check(not actor._try_fire_ready(),prefix+str(rank)+" cannot bypass unfinished reload")
		check(is_equal_approx(float(Ring.ordinary_slot(actor,actor.weapon,"hull").fraction),1.0),prefix+str(rank)+" ring starts full")
		# Interrupt almost immediately; the talent must not rely on a long channel first.
		var elapsed: float = 0.05
		actor._physics_process(elapsed)
		check(is_equal_approx(actor._cd_timer,interval-elapsed),prefix+str(rank)+" channel advances reload once",actor._cd_timer)
		var work: float = actor.special.get("temporal_work",0)
		check(is_equal_approx(work,120.0*elapsed),prefix+str(rank)+" erase rate unchanged",work)
		actor.order_stop()
		actor.set_fire_stance("none")
		check(not AlliedAbilities.frozen(target),prefix+str(rank)+" interruption releases freeze immediately")
		if mode==MatchRules.EXTENDED:
			check(actor.special.has(Talents.BOOK) and actor.special[Talents.BOOK].left==8+rank,prefix+str(rank)+" window begins at interruption")
		else:
			check(not actor.special.has(Talents.BOOK),prefix+str(rank)+" RA2 has no talent bookmark")
		# Include a full second of player reaction time after the reload finishes.
		actor._physics_process(interval-elapsed+1.0)
		if mode==MatchRules.EXTENDED:
			check(actor.special.has(Talents.BOOK) and actor.special[Talents.BOOK].left>0,prefix+str(rank)+" immediate interruption retains a usable reaction window")
		actor.order_target(target,false,false)
		actor.aim_dir = Vector2.RIGHT
		check(actor._try_fire_ready(),prefix+str(rank)+" actual refire reconnects")
		check(is_equal_approx(float(actor.special.get("temporal_work",-1)),work*0.5 if mode==MatchRules.EXTENDED else 0.0),prefix+str(rank)+" reconnection inherits immediately")
		AlliedAbilities.release_temporal(actor)
		actor.order_stop()
		actor.set_fire_stance("none")
		actor._physics_process(11.1)
		check(not actor.special.has(Talents.BOOK),prefix+str(rank)+" expiry still clears bookmark")
		# Multiplicative stacking, and the ring uses the same interval as firing.
		actor.bonuses.veteran_rof = 0.6
		actor.add_buff("cooldown",20,0.25)
		actor.order_target(target,false,false)
		actor._cd_timer = 0
		check(actor._try_fire_ready() and is_equal_approx(actor._cd_timer,interval*0.6*0.75),prefix+str(rank)+" veteran and buff multiply once")
		actor._cd_timer *= 0.5
		check(is_equal_approx(float(Ring.ordinary_slot(actor,actor.weapon,"hull").fraction),0.5),prefix+str(rank)+" ring half matches real reload")
		AlliedAbilities.release_temporal(actor)
		battle.units.erase(actor)
		battle.units.erase(target)
		actor.free()
		target.free()
	var other = battle.spawn_unit("CLEG","enemy",Vector2(1200,1200))
	check(Talents.cooldown_multiplier(other)==1.0,prefix+" enemy cannot borrow player talent")
	other.unit_id = "E1"
	other.side = "ally"
	check(Talents.cooldown_multiplier(other)==1.0,prefix+" other unit unchanged")
	other.unit_id = "CLEG"
	BattleRequest.combat_context.unit_talents = {}
	check(Talents.cooldown_multiplier(other)==1.0,prefix+" unequipped talent unchanged")
	await finish()
