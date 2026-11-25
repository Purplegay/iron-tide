extends Node
const Fog=preload("res://scripts/world/fog_of_war.gd")
var checks:Array=[]
var failed:=0
func check(name:String,ok:bool):
	checks.append({"name":name,"passed":ok})
	if not ok:failed+=1
func _ready():run.call_deferred()
func run():
	BattleRequest.house_teams={"ally":"a","enemy":"b","ai2":"a"}
	var fog=Fog.new();fog.width=24;fog.sight_clock=10
	for side in ["ally","enemy","ai2"]:
		fog.visible_cells[side]=PackedByteArray();fog.visible_cells[side].resize(576)
		fog.explored_cells[side]=PackedByteArray();fog.explored_cells[side].resize(576)
		fog.sight_until[side]={}
	for point in [Vector2.ZERO,Vector2(120,120),Vector2(159.99,200.01),Vector2(480,480),Vector2(960,960),Vector2(-200,-200)]:
		for side in fog.visible_cells:
			fog.visible_cells[side].fill(0);fog.sight_until[side].clear()
		fog._reveal("ally",point,fog.FIRE_REVEAL_RADIUS,2.0)
		var shot={"side":"ally","position":point}
		check("live leases cover exact raster "+str(point),fog._held_covers_firing(shot))
		for observer in ["ally","ai2"]:
			var held:Dictionary=fog.sight_until[observer]
			for index in held.keys():
				var deadline=held[index]
				held.erase(index)
				check("missing cell requires full rebuild %s/%s/%s"%[point,observer,index],not fog._held_covers_firing(shot))
				held[index]=fog.sight_clock
				check("equal deadline is expired %s/%s/%s"%[point,observer,index],not fog._held_covers_firing(shot))
				held[index]=deadline
		check("unrelated enemy leases not required "+str(point),fog._held_covers_firing(shot))
	fog.free()
	var world=Battle.new()
	world.effects_root=Node2D.new();world.projectiles_root=Node2D.new()
	var probe=preload("res://tests/fog_fire_cover_process.gd").new()
	probe.battle=world;probe.width=24;probe.sight_clock=10
	for side in ["ally","enemy","ai2"]:
		var bytes=PackedByteArray();bytes.resize(576)
		probe.visible_cells[side]=bytes.duplicate();probe.explored_cells[side]=bytes.duplicate();probe.sight_until[side]={}
	add_child(probe);probe.set_process(false)
	probe._reveal("ally",Vector2(480,480),probe.FIRE_REVEAL_RADIUS,2.0)
	probe.firing_positions[1]={"side":"ally","position":Vector2(480,480),"remaining":0.001}
	probe._process(0.01)
	check("covered shot record expires immediately without full rebuild",probe.firing_positions.is_empty() and probe.rebuild_count==0)
	check("covered cells remain visible",probe.is_visible_at("ally",Vector2(480,480)))
	probe.firing_positions[2]={"side":"ally","position":Vector2(120,120),"remaining":0.001}
	probe._process(0.01)
	check("unheld shot expiry still rebuilds immediately",probe.firing_positions.is_empty() and probe.rebuild_count==1)
	probe._process(0.11)
	check("ordinary scouting cadence still rebuilds",probe.rebuild_count==2)
	var scout=Building.new();scout.side="ally";scout.sight=300;scout.position=Vector2(800,800);scout.weapon={}
	world.buildings=[scout]
	probe._reveal("ally",scout.position,probe.FIRE_REVEAL_RADIUS)
	probe.firing_positions[4]={"side":"ally","position":scout.position,"remaining":0.001}
	probe._process(0.01)
	check("current scout avoids redundant expiry rebuild",probe.firing_positions.is_empty() and probe.rebuild_count==2)
	scout.hp=0
	probe.firing_positions[5]={"side":"ally","position":scout.position,"remaining":0.001}
	probe._process(0.01)
	check("next process rechecks destroyed current scout",probe.firing_positions.is_empty() and probe.rebuild_count==3)
	world.buildings=[];scout.free()
	probe.firing_positions[3]={"side":"ally","position":Vector2(480,480),"remaining":0.001}
	world.paused=true;probe._process(5.0)
	check("pause keeps shot and clock unchanged",probe.firing_positions.size()==1 and probe.rebuild_count==3)
	probe.free();world.effects_root.free();world.projectiles_root.free();world.free()
	FileAccess.open(OS.get_environment("IRON_TIDE_REPORT_DIR").path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed==0 else 1)
