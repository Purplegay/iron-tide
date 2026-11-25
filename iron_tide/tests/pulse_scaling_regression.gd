extends "res://tests/electric_cards_regression.gd"

func exercise(mode:String) -> void:
	start(mode);battle.fog=null
	BattleRequest.combat_context.bonuses=MatchRules.neutral_bonuses()
	BattleRequest.combat_context.unit_bonus={}
	var gi=make("E1","ally",Vector2(1000,1000))
	var radius:float=gi.deployed_weapon().range
	check(is_equal_approx(radius,5*Ra2Damage.PX_PER_CELL),prefix+"GI normal deployed range is five cells")
	check(GameData.get_skill(Cards.PULSE).radius==radius,prefix+"pulse definition uses GI deployed weapon radius")
	clear_units()
	for id in ["SHK","TTNK"]:
		for rank in 4:
			equip(id,Cards.PULSE,"",rank)
			var actor=make(id,"ally",Vector2(1200,1200))
			var idx:=UnitSkillLayout.index(actor,1)
			if mode==MatchRules.RA2:
				check(idx<0,prefix+"no extension pulse "+id+str(rank));clear_units();continue
			var ab:Ability=actor.skills[idx]
			var ratio:float=[0.4,0.6,0.8,1.0][rank]
			check(is_equal_approx(ab.value,ratio) and ab.radius==radius,"rank ratio and radius "+id+str(rank))
			var target=make("HTNK","enemy",actor.position+Vector2.RIGHT*(radius-1))
			var edge=make("HTNK","enemy",actor.position+Vector2.DOWN*radius)
			var outside=make("HTNK","enemy",actor.position+Vector2.LEFT*(radius+1))
			target.position=actor.position+Vector2.RIGHT*(radius-1)
			edge.position=actor.position+Vector2.DOWN*radius
			outside.position=actor.position+Vector2.LEFT*(radius+1)
			var base:float=actor._active_weapon().damage
			check(actor.use_ability(idx),"native weapon pulse cast "+id+str(rank))
			check(absf((target.max_hp-target.hp)-floorf(base*ratio))<=1,"actual native attack scales pulse damage "+id+str(rank))
			check(edge.hp<edge.max_hp and outside.hp==outside.max_hp,"inclusive five-cell edge; outside excluded")
			# Change the real weapon and offense bonuses: no fixed card damage or double scaling.
			actor.weapon=actor.weapon.duplicate(true);actor.weapon.damage=200.0;actor._ra2_weapon_override={}
			actor.bonuses.attack_bonus=1.5;actor.bonuses.veteran_attack=2.0
			actor.skill_power=99
			var before:float=target.hp
			ab.cd_left=0;actor.use_ability(idx)
			check(is_equal_approx(before-target.hp,float([240,360,480,600][rank])),"current attack and veteran bonuses applied once; skill training excluded")
			# A pre-change saved ability had fixed damage and the two-cell radius.
			ab.value=float([100,120,140,160][rank]);ab.radius=110;ab.cd_left=7.25
			BattleRequest.combat_context.card_strength_overrides[Cards.PULSE]=[1,1.2,1.4,1.6][rank]
			var codec=BattleSaves.Snapshot.new()
			var saved:Dictionary=codec.capture(battle)
			codec.restore(battle,saved)
			actor=battle.units.filter(func(u):return u.side=="ally")[0]
			ab=actor.skills[UnitSkillLayout.index(actor,1)]
			check(is_equal_approx(ab.value,ratio) and ab.radius==radius and ab.cd_left==7.25,"legacy fixed value migrates; saved rank and remaining cooldown preserved")
			check(is_equal_approx(BattleRequest.card_scale(Cards.PULSE)*0.4,ratio),"legacy battle future production uses new curve")
			var text:String=MetaProgress.Academy.skill_description(GameData.get_skill(Cards.PULSE),rank)
			check(text.contains(str([40,60,80,100][rank])+"%") and text.contains("5 格"),"description shows attack percent and five-cell radius")
			clear_units()
	await finish()
