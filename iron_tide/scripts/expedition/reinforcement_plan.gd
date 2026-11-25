extends RefCounted

const Army=preload("res://scripts/expedition/army.gd")
const SECONDS_PER_COST_UNIT := 30.0
const MEMBER := "expedition_legion_member"
const DISCOUNTS := "chrono_discounts"
const ANCHOR := "chrono_anchor"

static func unit_cost(id:String) -> float:
	return maxf(0.0,float(GameData.get_unit(id).get("cost",0)))

static func base_delay(id:String,hero_id:String,run:Dictionary) -> float:
	# Heroes use the same cost-based arrival timer as every other unit.
	return unit_cost(id)/100.0*SECONDS_PER_COST_UNIT

static func key(row:Dictionary) -> String:
	return str(row.id)+":"+str(row.get("hero",""))+":"+str(row.get("variant",""))

static func cap(run:Dictionary) -> float:
	return (5+preload("res://scripts/expedition/relics.gd").level(run,ANCHOR))/10.0

static func delay_for(id:String,hero_id:String,run:Dictionary,variant:="") -> float:
	var base:=base_delay(id,hero_id,run)
	var discount:=float(run.get(DISCOUNTS,{}).get(key({"id":id,"hero":hero_id,"variant":variant}),0.0))
	return maxf(0.0,base-minf(base*cap(run),maxf(0.0,discount)))

static func radio_copies(pending:Array,initial:Array,clock:float) -> Array:
	var originals:=pending.filter(func(row):return not row.get("radio_copy",false))
	var replay:=originals.is_empty()
	var result:Array=[]
	for row:Dictionary in (initial if replay else originals):
		if row.get("radio_marked",false) or not str(row.get("hero","")).is_empty() or int(preload("res://scripts/core/yr_death_rules.gd").type_data(row.id).get("buildlimit",-1))>0:continue
		var copy:=row.duplicate(true)
		copy.radio_copy=true
		if replay:copy.due=clock+float(row.due)
		else:row.radio_marked=true
		result.append(copy)
	return result

static func build(run:Dictionary) -> Array:
	var result:Array=[]
	var heroes:Array=[]
	for source:Dictionary in Army.inventory(run):
		var row:Dictionary=source.duplicate(true)
		var hero:=str(row.get("hero",""))
		if row.id not in run.get("active_roster",[]) and hero.is_empty():continue
		if not hero.is_empty():heroes.append(hero)
		row.due=delay_for(str(row.id),hero,run,str(row.get("variant","")))
		row.cost=unit_cost(str(row.id))
		result.append(row)
	for hero:String in preload("res://scripts/expedition/heroes.gd").owned(run):
		if hero in heroes or hero in preload("res://scripts/expedition/heroes.gd").wounded(run):continue
		result.append({"id":hero,"hero":hero,"variant":"","hp":1.0,"rank":0,"xp":0.0,"due":delay_for(hero,hero,run),"cost":unit_cost(hero)})
	preload("res://scripts/expedition/research.gd").accelerate(result,run)
	result.sort_custom(func(a:Dictionary,b:Dictionary)->bool:
		if not is_equal_approx(float(a.due),float(b.due)):return float(a.due)<float(b.due)
		if not is_equal_approx(float(a.cost),float(b.cost)):return float(a.cost)<float(b.cost)
		return str(a.id)<str(b.id))
	return result

# Only deployed legion members and still-pending legion entries count. Local
# factory production never affects either the roster or the casualty fraction.
static func carry(run:Dictionary,world,survivors:Array) -> Dictionary:
	var initial:Array=world.allied_state.get("expedition_legion_initial",[])
	if initial.is_empty():return run.get(DISCOUNTS,{}).duplicate(true)
	var counts:={}
	for row:Dictionary in initial:counts[key(row)]=int(counts.get(key(row),0))+1
	var remaining:=0
	for row:Dictionary in survivors:
		var k:=key(row)
		if int(counts.get(k,0))>0:remaining+=1;counts[k]-=1
	var retention:=clampf(float(remaining)/initial.size(),0.0,1.0)
	var clock:=maxf(0.0,float(world.allied_state.get("expedition_reinforcement_clock",0.0)))
	var result:Dictionary=run.get(DISCOUNTS,{}).duplicate(true)
	for row:Dictionary in initial:
		var base:=base_delay(str(row.id),str(row.get("hero","")),run)
		# Calculate from the old state, not repeated rows of this batch.
		var previous:=clampf(float(run.get(DISCOUNTS,{}).get(key(row),0.0)),0.0,base*cap(run))
		result[key(row)]=minf(base*cap(run),previous+minf(clock,float(row.due))*0.5)*retention
	return result
