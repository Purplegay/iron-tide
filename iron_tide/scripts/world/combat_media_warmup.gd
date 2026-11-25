extends Node
## Battle-owned strong references prevent repeat decompression of death textures.
## Resolve existing roster media before the first simulation tick; new roster types
## use one non-blocking threaded request at a time during play. No RNG/playback.
const DeathRules=preload("res://scripts/core/yr_death_rules.gd")
var world
var types:Dictionary={}
var weapons:Dictionary={}
var jobs:Dictionary={}
var queued:Dictionary={}
var held:Dictionary={}
var loading := ""
var scan_left:=0.0

static func install(battle) -> Node:
 var node=load("res://scripts/world/combat_media_warmup.gd").new()
 node.world=battle
 battle.add_child(node)
 node.scan()
 # Startup occurs before gameplay resumes, including restored paused saves.
 while not node.jobs.is_empty():
  var path:String=node.jobs.keys()[0]
  node.resolve(path,load(path))
  node.jobs.erase(path)
 return node

func enqueue(path:String,kind:String,id:String) -> void:
 if queued.has(path) or not ResourceLoader.exists(path):return
 queued[path]=true
 jobs[path]={"kind":kind,"id":id}

func sound(id:String) -> void:
 for file in GameData.ra2_sound_files(id):enqueue(GameData.ra2_sfx_path(str(file)),"sound",str(file))

func effect(id:String) -> void:
 if not id.is_empty():enqueue(RA2Art.FX_DIR+id.to_upper()+".png","fx",id)

func weapon(w:Dictionary) -> void:
 var id:=str(w.get("ra2_weapon_id",""))
 if id.is_empty() or weapons.has(id):return
 weapons[id]=true
 sound(str(w.get("report","")))
 for image in GameData.ra2_muzzle_anims(id):effect(str(image))
 for image in GameData.ra2_impact_anims(str(w.get("ra2_warhead",""))):effect(str(image))
 var projectile:Dictionary=GameData.ra2_projectile(str(w.get("ra2_projectile","")))
 effect(str(projectile.get("image","")))
 var child:=str(projectile.get("extra",{}).get("ShrapnelWeapon",""))
 if not child.is_empty():weapon(AlliedAbilities.weapon(child.trim_prefix("YR_CAP_")))

func actor(actor_) -> void:
 var id:String=actor_.unit_id if actor_ is Unit else actor_.building_id
 if types.has(id):return
 types[id]=true
 for value in actor_.data.values():
  if value is Dictionary and value.has("ra2_weapon_id"):weapon(value)
 weapon(actor_._active_weapon() if actor_ is Unit else actor_.weapon)
 var row:=DeathRules.type_data(id)
 for image in DeathRules.names(row,"explosion"):
  enqueue("res://assets/ra2/death/"+str(image).to_upper()+".png","death",str(image))
 sound(str(actor_.data.get("voice",{}).get("die","")))

func scan() -> void:
 for actor_ in world.units:
  if is_instance_valid(actor_):actor(actor_)
 for actor_ in world.buildings:
  if is_instance_valid(actor_):actor(actor_)

func resolve(path:String,resource:Resource) -> void:
 if resource==null:return
 held[path]=resource
 var job:Dictionary=jobs[path]
 if job.kind=="fx":
  var entry:=RA2Art.fx(job.id)
  sound(str(entry.get("sound","")))
 elif job.kind=="sound":Ra2Sfx._stream(job.id)

func _process(delta:float) -> void:
 scan_left-=delta
 if scan_left<=0:
  scan_left=0.25
  scan()
 if loading.is_empty():
  if jobs.is_empty():return
  var path:String=jobs.keys()[0]
  if ResourceLoader.load_threaded_request(path)!=OK:
   jobs.erase(path)
   return
  loading=path
 if ResourceLoader.load_threaded_get_status(loading)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:return
 resolve(loading,ResourceLoader.load_threaded_get(loading))
 jobs.erase(loading)
 loading=""

func _exit_tree() -> void:
 if not loading.is_empty():ResourceLoader.load_threaded_get(loading)
