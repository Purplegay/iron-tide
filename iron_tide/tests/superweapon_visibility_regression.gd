extends "res://tests/special_mechanics_regression.gd"
const Fog = preload("res://scripts/world/fog_of_war.gd")
const Soviet = preload("res://scripts/units/soviet_specials.gd")
const TARGET := Vector2(1800,1800)
func _ready():
 output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
 if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
 for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
  for side in ["ally","enemy"]:
   for id in ["NAMISL","GAWEAT","NAIRON","GACSPH"]:
    arena(mode)
    await exercise_visibility(side,id)
    await finish()
 for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
  await exercise_teams(mode)
  await finish()
 FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
 get_tree().quit(0 if failed==0 else 1)
func exercise_visibility(side:String,id:String):
 var observer:="enemy" if side=="ally" else "ally"
 var label:=prefix+side+" "+id+" "
 var source=add(id,side,Vector2(400,400))
 battle.power_low=false;battle.enemy_power.low=false
 var origin:=TARGET-Vector2(350,0) if id=="GACSPH" else TARGET
 var unit=spawn("MTNK",side,origin)
 unit.sight=0;unit.attack_range=0
 battle.power_low=false;battle.enemy_power.low=false
 battle.fog=Fog.new();battle.add_child(battle.fog);battle.fog.setup(battle)
 var fog=battle.fog
 fog.explored_cells[side][fog._index(TARGET)]=1
 check(not fog.is_visible_at(observer,TARGET),label+"target initially hidden")
 source._sw_charge=0
 check(not source.fire_superweapon(TARGET,origin) and not fog.is_visible_at(observer,TARGET),label+"uncharged attempt does not reveal target")
 source._sw_charge=source.sw_recharge()
 check(source.fire_superweapon(TARGET,origin),label+"real launch succeeds")
 check(fog.is_visible_at(observer,source.position) and fog.is_visible_at(observer,TARGET),label+"source and target immediately visible")
 check(fog.is_explored_at(observer,TARGET),label+"target enters explored terrain")
 if observer=="ally":
  check(fog.mask_image.get_pixelv(Vector2i(TARGET/Fog.CELL)).a<0.01,label+"rendered fog mask opens")
  check(unit.visible,label+"target actor render visibility updates")
 check(not fog.is_visible_at(observer,Vector2(200,2100)),label+"unrelated map stays hidden")
 if id in ["NAMISL","GAWEAT"]:
  fog._process(11.0)
  check(fog.is_visible_at(observer,TARGET),label+"ongoing launch survives initial ten-second window")
  battle.buildings.erase(source);source.free()
  fog.rebuild()
  check(fog.is_visible_at(observer,TARGET),label+"ongoing effect survives launcher destruction")
  BattleRequest.skirmish_config.fog_of_war=true
  var saved:Dictionary=Snapshot.new().capture(battle)
  check(BattleSaves.validate(saved).is_empty(),label+"active effect visibility validates for save")
  Snapshot.new().restore(battle,saved)
  battle.paused=false;get_tree().paused=false
  fog=battle.fog
  check(fog.is_visible_at(observer,TARGET),label+"restore retains active target visibility")
  if id=="NAMISL":Soviet.tick_world(battle,60.0)
  else:LightningStorm.tick(battle,60.0)
  check(battle.allied_state.get("soviet_nukes",[]).is_empty() and LightningStorm.storms(battle).is_empty(),label+"real effect reaches end")
  # Aftereffect visibility must survive even if the launcher no longer exists.
  check(fog.is_visible_at(observer,TARGET),label+"impact remains visible")
 else:
  battle.buildings.erase(source);source.free()
  for actor in battle.units.duplicate():actor.free()
  battle.units.clear()
  fog._scouts.clear()
 fog._process(9.9)
 check(fog.is_visible_at(observer,TARGET),label+"post-effect ten-second visibility retained")
 fog._process(0.2)
 check(not fog.is_visible_at(observer,TARGET) and fog.is_explored_at(observer,TARGET),label+"expiry restores fog but keeps explored terrain")

func exercise_teams(mode:String):
 BattleRequest.configure_skirmish(mode,{"map_layout":"yr_isleland","map_size":2400,"fog_of_war":true,"houses":[
  {"country":"美国","team":1},{"country":"美国","team":1},
  {"country":"苏俄","team":2},{"country":"苏俄","team":2},
  {"country":"美国","team":3},{"country":"美国","team":3}]})
 screen=load("res://scenes/battle.tscn").instantiate();add_child(screen)
 screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
 for actor in battle.units+battle.buildings:actor.free()
 battle.units.clear();battle.buildings.clear()
 for group in ["obstacles","resource_nodes"]:
  for node in get_tree().get_nodes_in_group(group):node.free()
 battle.water_rects.clear();battle.path_service.water_rects.clear();battle._refresh_pathing()
 battle.fog.free();battle.fog=null
 battle.gm_unit_lab=true
 for i in 130:
  var actor=battle.spawn_unit("MTNK","ally",Vector2(200+i%10,200+i/10))
  actor.sight=0;actor.attack_range=0
 var source=add("GAWEAT","ally",Vector2(400,400))
 battle.power_low=false;battle.paused=false;battle.ended=false;get_tree().paused=false
 battle.fog=Fog.new();battle.add_child(battle.fog);battle.fog.setup(battle)
 var fog=battle.fog
 check(fog.visible_cells.size()==6,mode+" six-house visibility fixture")
 for observer in fog.visible_cells:check(not fog.is_visible_at(observer,TARGET),mode+observer+" hidden target before launch")
 source._sw_charge=source.sw_recharge()
 check(source.fire_superweapon(TARGET),mode+" friendly-team launcher fires storm")
 for observer in fog.visible_cells:
  check(fog.is_visible_at(observer,TARGET) and fog.is_explored_at(observer,TARGET),mode+observer+" launch visible to all three teams")
 fog._process(11.0)
 for observer in fog.visible_cells:check(fog.is_visible_at(observer,TARGET),mode+observer+" batched scout masks preserve active reveal")
 check(BattleSaves.validate(Snapshot.new().capture(battle)).is_empty(),mode+" six-house held sight is valid save data")
