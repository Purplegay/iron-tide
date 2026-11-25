extends "res://tests/base_recovery_regression.gd"
const Expansion = preload("res://scripts/units/progression_expansion.gd")
const Visual = preload("res://scripts/units/expansion_visual.gd")
var draws := 0
var timings: Array = []

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2); return
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		start(mode)
		var actor: Unit = battle.spawn_unit("MTNK", "enemy", Vector2(800,800))
		exercise_queries(actor)
		exercise_visual_gate(actor)
		if mode == MatchRules.EXTENDED:
			exercise_spent_shot(actor)
			await exercise_redraw(actor)
			actor.side="ally";actor.passive={};actor.special={};actor.hp=actor.max_hp
			BattleRequest.combat_context.unit_talents={}
			await exercise_redraw(actor)
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"timings":timings},"  "))
	get_tree().quit(0 if failed==0 else 1)

func reference_alive(actor) -> bool:
	return is_instance_valid(actor) and not actor.is_queued_for_deletion() and actor.hp>0.0 and not actor._dead

func exercise_queries(actor: Unit) -> void:
	var point := ForceFirePoint.new()
	for target in [actor, battle.buildings[0], point, null]:
		if target == null:
			check(not AlliedAbilities.alive(target),prefix+"null actor remains invalid")
			continue
		var old_hp: float = target.hp
		var old_dead: bool = target._dead
		for hp in [-1.0,0.0,1.0,100.0]:
			for dead in [false,true]:
				target.hp=hp;target._dead=dead
				check(AlliedAbilities.alive(target)==reference_alive(target),prefix+"typed and generic actor liveness matches original")
		target.hp=old_hp;target._dead=old_dead
	var queued: Unit = battle.spawn_unit("E1","enemy",Vector2(900,800))
	queued.queue_free()
	check(not AlliedAbilities.alive(queued),prefix+"queued actor is rejected before deletion")
	var freed: Unit = Unit.new()
	freed.free()
	check(not AlliedAbilities.alive(freed),prefix+"freed actor remains invalid")
	var sum := 0
	var begun := Time.get_ticks_usec()
	for i in 20000: sum+=int(reference_alive(actor))
	var before := Time.get_ticks_usec()-begun
	begun=Time.get_ticks_usec()
	for i in 20000: sum+=int(AlliedAbilities.alive(actor))
	timings.append({"mode":BattleRequest.rules_mode,"reference_alive_us":before,"typed_alive_us":Time.get_ticks_usec()-begun,"calls_per_variant":20000})
	check(sum==40000,prefix+"query timing loops preserve result")

func exercise_visual_gate(actor: Unit) -> void:
	actor.passive={};actor.special={};actor.selected=false
	for state in [{},{"shot_idle":10.0,"arc_count":0},{"rest":3,"shot_origin":Vector2.ONE,"volley":8,"scrap_idle":2,"scrap_drop":1,"prism_damage":0.0}]:
		actor.special.progression_v1=state
		check(not Visual.has_visual_state(actor,state) and Visual.entries(actor).is_empty(),prefix+"bookkeeping-only state emits no overlay")
	for key in ["arc_count","mirror_shield","mirrors","capacitor","afterburn","tracking","dive_cloak","future_visual_effect","prism_damage"]:
		check(Visual.has_visual_state(actor,{key:1}),prefix+"active or new visual state falls back: "+key)
	actor.special.expansion_temporary={}
	check(Visual.has_visual_state(actor,{}),prefix+"temporary summons retain visuals")
	actor.special.erase("expansion_temporary")
	actor.passive={"id":"ps_watch_succession"}
	check(Visual.has_visual_state(actor,{}),prefix+"succession availability retains label")
	actor.passive={};actor.selected=true;actor.special.academy_hero="E1"
	check(Visual.has_visual_state(actor,{}),prefix+"selected hero range ring retained")
	actor.selected=false;actor.special={}

func count_draw() -> void:
	draws+=1

func settle_draws() -> void:
	for i in 3: await get_tree().process_frame

func exercise_redraw(actor: Unit) -> void:
	actor.visible=true
	if not actor.draw.is_connected(count_draw):actor.draw.connect(count_draw)
	actor.queue_redraw()
	await settle_draws()
	check(draws>0,prefix+"draw counter observes actual CanvasItem drawing")
	draws=0
	actor.special.progression_v1={"shot_idle":2.0,"arc_count":0}
	var hp_before:=actor.hp
	Expansion.tick(actor,1.0/15.0)
	await settle_draws()
	check(draws==0,prefix+"idle bookkeeping does not rebuild unchanged unit art",draws)
	check(is_equal_approx(actor.special.progression_v1.shot_idle,2.0+1.0/15.0) and actor.hp==hp_before,prefix+"idle clock advances without changing health")
	actor.special.progression_v1.arc_count=2
	Expansion.tick(actor,1.0/15.0)
	await settle_draws()
	check(draws>0 and actor.special.progression_v1.arc_count==0,prefix+"clearing a displayed arc counter redraws immediately")
	draws=0
	actor.special.progression_v1.future_effect=true
	Expansion.tick(actor,1.0/15.0)
	await settle_draws()
	check(draws>0,prefix+"unknown effect keeps original redraw path")
	draws=0
	actor.special.progression_v1={"arc_count":0}
	actor.hp=actor.max_hp*0.3
	Expansion.tick(actor,1.0/15.0)
	await settle_draws()
	check(draws>0,prefix+"low-health idle actor preserves animated smoke redraw")
	draws=0
	actor.queue_redraw()
	await settle_draws()
	check(draws>0,prefix+"other animation redraw requests remain effective")

func exercise_spent_shot(actor: Unit) -> void:
	actor.side="enemy";actor.passive={}
	var state:Dictionary={"arc_count":0,"shot_idle":2.5,"rest":0.0,"shot_origin":Vector2(80,90),"scrap_idle":0,"scrap_drop":0,"volley":30,"prism_damage":0.0}
	actor.special.progression_v1=state.duplicate(true)
	var begun:=Time.get_ticks_usec()
	for i in 2000:
		Expansion.Cards.tick(actor,1.0/15.0)
		Expansion.Talents.tick(actor,1.0/15.0)
		Expansion.Heroes.tick(actor,1.0/15.0)
	var reference_us:=Time.get_ticks_usec()-begun
	var expected:Dictionary=actor.special.progression_v1.duplicate(true)
	actor.special.progression_v1=state.duplicate(true)
	begun=Time.get_ticks_usec()
	var accepted:=0
	for i in 2000:
		accepted+=int(preload("res://scripts/units/unit_expansion_idle.gd").try_tick(actor,1.0/15.0))
	var idle_us:=Time.get_ticks_usec()-begun
	check(accepted==2000 and actor.special.progression_v1==expected,"real spent-shot state preserves every field across 2000 ticks")
	timings.append({"scenario":"real saved spent-shot state","calls_per_variant":2000,"original_handlers_us":reference_us,"idle_handlers_us":idle_us})
