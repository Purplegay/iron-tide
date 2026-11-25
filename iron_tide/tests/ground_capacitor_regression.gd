extends "res://tests/leizhu_cards_regression.gd"
const Talents=preload("res://scripts/units/expansion_talents.gd")
const Rules=preload("res://scripts/units/expansion_rules.gd")
const Token=preload("res://scripts/units/ground_capacitor_token.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	for hero in [false,true]:
		for rank in 4:await group_hit(rank,hero)
	await wait_and_expire()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("CAPACITOR checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func capacitor(rank:int,hero:bool):
	var unit
	if hero:unit=cards_hero()
	else:
		MetaProgress.reset_save();boot("BORIS")
		unit=battle.spawn_unit("TTNK","ally",Vector2(1000,1000))
	BattleRequest.combat_context.unit_talents.TTNK={"ground_capacitor":rank}
	unit.order_stop()
	var state:=Rules.state(unit)
	state.shot_idle=3.0
	Talents.tick(unit,2.0)
	unit.position+=Vector2(65,0)
	Talents.tick(unit,0.01)
	check(state.has("capacitor") and state.capacitor.point==Vector2(1000,1000),"normal prepare and departure create anchored capacitor")
	return unit

func group_hit(rank:int,hero:bool) -> void:
	var unit=capacitor(rank,hero)
	var state:=Rules.state(unit)
	var center:Vector2=state.capacitor.point
	var victims:Array=[]
	var before:Array=[]
	var damage:Array=[]
	for offset in [Vector2.ZERO,Vector2(54.99,0),Vector2(-55,0),Vector2(0,55)]:
		var victim=target("HTNK","enemy",center+offset)
		victims.append(victim);before.append(victim.hp)
		damage.append(expected(unit,victim,[.15,.2,.25,.3][rank]))
	var outside=target("HTNK","enemy",center+Vector2(55.01,0))
	var friendly=target("HTNK","ally",center+Vector2(0,10))
	var air=target("ORCA","enemy",center+Vector2(0,-10));air.logistics.air_lift=1.0
	var token=unit.get_meta(Token.META).get_ref()
	# A lethal first victim must not end iteration or skip remaining targets.
	victims[0].hp=1.0;before[0]=1.0
	Talents.tick(unit,0.01)
	check(victims[0].hp<=0,"first victim can die without stopping group discharge")
	for i in range(1,victims.size()):
		check(is_equal_approx(before[i]-victims[i].hp,damage[i]),"every inner/boundary target receives one rank-scaled hit",[rank,hero,i,before[i]-victims[i].hp,damage[i]])
	check(outside.hp==100000 and friendly.hp==100000 and air.hp==100000,"outside boundary friendly and airborne targets unaffected")
	check(not state.has("capacitor") and token.is_queued_for_deletion(),"one discharge consumes capacitor and world marker")
	check(state.capacitor_cd>9.9,"group discharge preserves ten-second deployment cooldown")
	var after:float=victims[1].hp
	Talents.tick(unit,.1)
	check(victims[1].hp==after,"consumed capacitor cannot hit again next tick")
	await finish()

func wait_and_expire() -> void:
	var unit=capacitor(0,true)
	var state:=Rules.state(unit)
	var center:Vector2=state.capacitor.point
	var victim=target("HTNK","enemy",center+Vector2(55.01,0))
	Talents.tick(unit,.1)
	check(state.has("capacitor") and victim.hp==100000,"just outside radius does not trigger capacitor")
	victim.position=center+Vector2(55,0)
	Talents.tick(unit,.1)
	check(not state.has("capacitor") and victim.hp<100000,"entering exact one-cell boundary triggers discharge")
	await finish()
	unit=capacitor(0,true);state=Rules.state(unit)
	Talents.tick(unit,4.0)
	check(not state.has("capacitor"),"untriggered capacitor retains original lifetime")
	await finish()
