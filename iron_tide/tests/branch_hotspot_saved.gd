extends Node
const Reference=preload("res://tests/branch_hotspot_reference.gd")
const Tactics=preload("res://scripts/world/skirmish_tactics.gd")
const Economy=preload("res://scripts/world/skirmish_economy.gd")
const Access=preload("res://scripts/world/ai_base_access.gd")
const Micro=preload("res://scripts/world/skirmish_micro.gd")
const BeforeOutline=preload("res://tests/branch_outline_reference.gd")
const AfterOutline=preload("res://scripts/ui/attack_target_outlines.gd")
var checks:Array=[]
var failed:=0
var micro:Array=[]
var counts:Array=[]
var world
var old_outline=BeforeOutline.new()
var new_outline=AfterOutline.new()

class Dispatch extends RefCounted:
 var jobs:Array=[]
 func defer_job(_world,unit,kind,dt)->bool:
  jobs.append([unit,kind,dt]);return true

class CountWorld extends Node:
 var actual
 var units:Array=[]
 var buildings:Array=[]
 var calls:=0
 var paused:=false
 var ended:=false
 var camera
 var ai_dispatch=Dispatch.new()
 func actor_alive(actor)->bool:
  calls+=1;return actual.actor_alive(actor)
 func actor_visible_to(side,actor)->bool:return actual.actor_visible_to(side,actor)
 func roster_id(id,side)->String:return actual.roster_id(id,side)

class TestAI extends RefCounted:
 var battle
 var house_id:String
 var enemy_base:="soviet"
 var ai_state:Dictionary={}

func check(ok:bool,label:String):
 checks.append({"passed":ok,"name":label})
 if not ok:failed+=1;print("FAIL ",label)

func _ready():
 process_mode=Node.PROCESS_MODE_ALWAYS;get_tree().current_scene=null;run.call_deferred()

func pair(kind:String,ai,before:bool):
 var result:Array=[]
 match kind:
  "fighter":
   for u in ai.battle.units:
    result.append(Reference.fighter(ai.battle,u,ai.house_id) if before else Tactics.fighter(ai.battle,u,ai.house_id))
  "miners":
   result=[Reference.miners(ai,false),Reference.miners(ai,true)] if before else [Economy.miners(ai,false),Economy.miners(ai,true)]
  "sellable":
   for b in ai.battle.buildings:
    result.append(Reference.sellable(ai,b) if before else Access.sellable(ai,b))
  "micro":
   ai.ai_state={};ai.battle.ai_dispatch.jobs.clear()
   if before:Reference.micro_tick(ai,0.5)
   else:Micro.tick(ai,0.5)
   result=ai.battle.ai_dispatch.jobs.duplicate(true)
  "outline":
   var outline=old_outline if before else new_outline
   outline.refresh(ai.battle)
   result=[outline.marked.duplicate(),outline.friendly_marked.duplicate()]
 return result

func validate(proxy,label:String):
 for side in BattleRequest.house_teams:
  var ai=TestAI.new();ai.battle=proxy;ai.house_id=side
  for kind in ["fighter","miners","sellable","micro","outline"]:
   proxy.calls=0
   var expected=pair(kind,ai,true)
   var old_calls:int=proxy.calls
   proxy.calls=0
   var actual=pair(kind,ai,false)
   check(expected==actual,label+" "+side+" "+kind+" returns same identities/counts/queued decisions")
   if label=="saved":counts.append({"kind":kind,"side":side,"before":old_calls,"after":proxy.calls})

func run():
 var out:=OS.get_environment("IRON_TIDE_REPORT_DIR")
 if out.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
 var expected_meta=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("IRON_META")))
 check(MetaProgress.unit_cosmetics==expected_meta.get("unit_cosmetics",{}) and MetaProgress.attachment_positions==expected_meta.get("attachment_positions",{}),"actual frozen cosmetics loaded")
 DirAccess.make_dir_recursive_absolute(BattleSaves.DIRECTORY)
 DirAccess.copy_absolute(OS.get_environment("IRON_SAVE"),BattleSaves.slot_path("slot1"))
 if not BattleSaves.load_into_scene("slot1").ok:get_tree().quit(2);return
 while get_tree().current_scene==null:await get_tree().process_frame
 get_tree().paused=true
 world=get_tree().current_scene.battle
 var proxy=CountWorld.new();add_child(proxy);proxy.actual=world;proxy.units=world.units.duplicate();proxy.buildings=world.buildings.duplicate();proxy.camera=world.camera
 # The micro policy normally exits when the tree is paused; disable the actual
 # battle subtree instead while invoking its real policy with a recording queue.
 get_tree().current_scene.process_mode=Node.PROCESS_MODE_DISABLED;get_tree().paused=false
 validate(proxy,"saved")
 var invalid=Node2D.new();invalid.free()
 proxy.units.append(null);proxy.units.append(invalid);proxy.buildings.append(null);proxy.buildings.append(invalid)
 validate(proxy,"freed/null candidates")
 proxy.units=world.units.duplicate();proxy.buildings=world.buildings.duplicate()
 var u:Unit=world.units[0];var hp:=u.hp;var dead:=u._dead;var side:=u.side;var embarked=u.embarked_in
 for state in ["zero_hp","dead_flag","other_owner","embarked"]:
  u.hp=hp;u._dead=dead;u.side=side;u.embarked_in=embarked
  if state=="zero_hp":u.hp=0
  if state=="dead_flag":u._dead=true
  if state=="other_owner":u.side="enemy"
  if state=="embarked":u.embarked_in=world.buildings[0]
  validate(proxy,state)
 u.hp=hp;u._dead=dead;u.side=side;u.embarked_in=embarked
 var b:Building=world.buildings[0];var building_hp:=b.hp;var building_dead:=b._dead;var construction:=b.under_construction
 for state in ["building_zero_hp","building_dead","under_construction"]:
  b.hp=building_hp;b._dead=building_dead;b.under_construction=construction
  if state=="building_zero_hp":b.hp=0
  if state=="building_dead":b._dead=true
  if state=="under_construction":b.under_construction=true
  validate(proxy,state)
 b.hp=building_hp;b._dead=building_dead;b.under_construction=construction
 var teams=BattleRequest.house_teams.duplicate(true)
 BattleRequest.house_teams.enemy=BattleRequest.house_teams.ally
 validate(proxy,"allied enemy seat")
 BattleRequest.house_teams=teams
 var queued=Unit.new();queued.side="enemy";queued.hp=100;queued.data={};proxy.units.append(queued);add_child(queued);queued.queue_free()
 validate(proxy,"queued deletion")
 proxy.units=world.units.duplicate()
 check(world.units.size()>300 and world.house_controllers.size()==5,"same six-house pressure checkpoint")
 # Alternating batches use real saved actors and real Battle queries. Only the
 # micro dispatch route uses a recording queue, and is reported separately.
 for kind in ["fighter","miners","sellable","outline","micro"]:
  for pass_index in 12:
   var elapsed:=0
   for repeat in 8:
    for owner in world.house_controllers:
     var ai=TestAI.new();ai.house_id=owner;ai.battle=proxy if kind=="micro" else world
     var begin:=Time.get_ticks_usec()
     pair(kind,ai,pass_index%2==0)
     elapsed+=Time.get_ticks_usec()-begin
   micro.append({"kind":kind,"variant":"before" if pass_index%2==0 else "after","us":elapsed,"batches":8*world.house_controllers.size()})
 FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro,"counts":counts,"units":world.units.size(),"buildings":world.buildings.size()}))
 get_tree().quit(0 if failed==0 else 1)
