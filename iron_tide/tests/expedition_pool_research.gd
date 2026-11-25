extends Node
const R=preload("res://scripts/expedition/research.gd")
var errors:=0
var checks:=0
func check(value:bool, label:String) -> void:
	checks+=1
	if not value:
		errors+=1
		push_error(label)
func _ready() -> void:
	if not OS.get_user_data_dir().contains("IronTidePoolResearchValidation"):
		get_tree().quit(2)
		return
	var ids:=MetaProgress.skill_draw_candidates().map(func(c):return c.id)
	for id in ["ap_carrier_reserve","ap_ivan_trigger","ap_chrono_return","ap_sonar_jam","ap_extra_volley","ps_swimming","ps_flank_cover","ps_rally_guard","ps_emergency_plate","ap_scout_flare"]:
		check(ids.has(id),"draw "+id)
		if GameData.get_skill(id).type=="active":check(preload("res://scripts/units/auto_w.gd").supported(id),"auto "+id)
	BattleRequest.rules_mode=MatchRules.EXTENDED
	BattleRequest.combat_context={"unit_talents":{"LCRF":{"fleet_cannon":3},"SAPC":{"fleet_rockets":3}},"card_ranks":{"ps_flank_cover":3}}
	var target:=Unit.new()
	var ally:=Unit.new()
	target.side="ally";ally.side="ally"
	add_child(target);add_child(ally)
	target.set_physics_process(false);ally.set_physics_process(false)
	ally.hp=100;ally.passive=GameData.get_skill("ps_flank_cover");ally._apply_passive()
	check(is_equal_approx(Unit.PoolCards.divert(target,100,null),90) and is_equal_approx(ally.hp,92),"cover 100 -> 90/8")
	target.special.sonar_reload_lock=2.5
	check(Unit.PoolCards.clock_rate(target,2)==0 and is_equal_approx(Unit.PoolCards.clock_rate(target,1),0.5),"reload freeze and partial tick")
	for id in ["SAPC","LCRF"]:
		target.unit_id=id;Unit.PoolCards.fleet_setup(target)
		check(target.weapon.has("damage") and target.attack_range>0 and target.special.fleet_ammo==5,"armed "+id)
	check(MetaProgress.talent_options("V3").size()==3,"V3 prior talents retained")
	check_research_dots()
	MetaProgress.academy.expedition_research={};MetaProgress.currency.cores=22300
	for branch in R.BRANCHES:
		check(not R.buy(branch,1),"skip blocked")
		for i in R.NODES[branch].size():check(R.buy(branch,i),"research "+branch+str(i))
		check(not R.buy(branch,R.NODES[branch].size()),"cap")
	check(MetaProgress.balance("cores")==0,"exact total price")
	const Income=preload("res://scripts/expedition/income.gd")
	MetaProgress.settled_matches={"expedition:old:1":{"credits":800,"cores":20},"expedition:old:2":{"credits":800,"cores":20,"strategy_points":1}}
	var run:={"id":"old","history":[{"stage":3,"income":{"credits":800,"cores":20}}]}
	var cores:=MetaProgress.balance("cores")
	check(Income.deliver(run,MetaProgress) and MetaProgress.balance("cores")==cores+20,"legacy and pending receipts")
	MetaProgress.load_save()
	check(Income.deliver(run,MetaProgress) and MetaProgress.balance("cores")==cores+20,"repeat settlement after reload")
	MetaProgress.currency.cores=3124
	MetaProgress.academy.expedition_research={}
	check(R.buy("army",0) and MetaProgress.balance("cores")==3024,"direct balance")
	MetaProgress.academy.strategy_points=77
	MetaProgress.save();MetaProgress.load_save();MetaProgress.load_save()
	check(MetaProgress.balance("cores")==3101 and not MetaProgress.academy.has("strategy_points"),"legacy balance folded once")
	const Icon=preload("res://scripts/ui/resource_cost_icon.gd")
	for resource in Icon.SHAPES:check(Icon.texture(resource)!=null,"cost icon "+resource)
	check(Icon.texture("tickets","diamonds").get_width()==48,"mixed cost")
	var rows:=[{"due":100.0},{"due":100.0},{"due":200.0},{"due":300.0},{"due":400.0},{"due":20.0,"hero":"TANY"}]
	R.accelerate(rows,{"research":{"army":10}})
	check(rows[0].due==88 and rows[1].due==88 and rows[2].due==176 and rows[3].due==264 and rows[4].due==400 and rows[5].due==20,"first three batches")
	print("POOL_RESEARCH checks=",checks," failures=",errors)
	get_tree().quit(int(errors>0))

func marked(control: Control) -> bool:
	var dot := control.get_node_or_null("UpgradeDot") as Control
	return dot != null and dot.is_visible_in_tree() and dot.mouse_filter == Control.MOUSE_FILTER_IGNORE

func dot_count(tree: Node) -> int:
	return tree.find_children("*", "Button", true, false).filter(marked).size()

func check_research_dots() -> void:
	MetaProgress.academy.expedition_research = {}
	MetaProgress.currency.cores = 99
	var menu = load("res://scenes/main.tscn").instantiate()
	var camp = load("res://scenes/expedition.tscn").instantiate()
	var base = load("res://scenes/expedition_research.tscn").instantiate()
	for scene in [menu, camp, base]: add_child(scene)
	var shortcut: Button = menu.find_children("*","Button",true,false).filter(func(b):return b.text=="远征养成")[0]
	var entry: Button = camp.find_children("*","Button",true,false).filter(func(b):return b.text=="远征研究")[0]
	var entries := [shortcut,entry,base.expedition_tab]
	check(not entries.any(marked) and dot_count(base.expedition_tree)==0,"99 cores: no research reminders")
	entry.pressed.emit()
	var dialog: AcceptDialog = camp.find_children("*","AcceptDialog",true,false)[0]
	MetaProgress.currency.cores = 100
	Events.meta_changed.emit()
	check(entries.all(marked) and dot_count(base.expedition_tree)==5 and dot_count(dialog)==5,"100 cores: all three entries and each first node marked")
	var first: Button = dialog.find_children("*","Button",true,false).filter(func(b):return b.text.begins_with(R.NODES.army[0]))[0]
	first.pressed.emit()
	check(R.current_level("army")==1 and MetaProgress.balance("cores")==0 and not entries.any(marked) and dot_count(dialog)==0 and dot_count(base.expedition_tree)==0,"purchase refreshes both trees and all entries immediately")
	MetaProgress.currency.cores = 199
	Events.meta_changed.emit()
	check(dot_count(dialog)==4,"second army level needs 200 cores, later levels stay unmarked")
	MetaProgress.currency.cores = 200
	Events.meta_changed.emit()
	check(dot_count(dialog)==5 and dialog.find_children("*","Button",true,false).any(func(b):return b.text.begins_with(R.NODES.army[1]) and marked(b)),"exact cost marks the next army level")
	MetaProgress.academy.expedition_research = {"army":10,"supply":10,"intel":10,"factory":10,"bargain":2}
	MetaProgress.currency.cores = 10000
	Events.meta_changed.emit()
	check(not entries.any(marked) and dot_count(dialog)==0,"completed research stays unmarked")
	for scene in [menu,camp,base]: scene.free()
	Events.meta_changed.emit()
