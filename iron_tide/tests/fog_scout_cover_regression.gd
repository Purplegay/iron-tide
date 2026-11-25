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
	var world=Battle.new()
	var fog=Fog.new();fog.battle=world;fog.width=40
	for side in ["ally","enemy","ai2"]:fog.visible_cells[side]=PackedByteArray()
	var unit=Unit.new();unit.side="ai2";unit.weapon={};unit.position=Vector2(800,800)
	world.units=[unit,null]
	var stale=Unit.new();stale.free();world.units.append(stale)
	var tested:=0
	for radius in [160.0,240.0,400.0]:
		unit.sight=radius
		for distance in [0.0,20.0,radius-120.02,radius-120.0,radius-119.99,radius]:
			for angle in [0.0,0.17,1.2,2.5,4.9]:
				var point=unit.position+Vector2.from_angle(angle)*distance
				var ok=fog._scout_covers_firing({"side":"ally","position":point},{})
				check("conservative containment %s/%s/%s"%[radius,distance,angle],ok==(distance<radius-120.01))
				if ok:
					var fire=Image.create(40,40,false,Image.FORMAT_L8);fire.fill(Color.BLACK)
					var scout=Image.create(40,40,false,Image.FORMAT_L8);scout.fill(Color.BLACK)
					Fog.SightBatch.raster_disc(fire,40,point,120)
					Fog.SightBatch.raster_disc(scout,40,unit.position,radius)
					var a=fire.get_data();var b=scout.get_data();var covered=true
					for i in a.size():
						if a[i]!=0 and b[i]==0:covered=false
					check("real raster subset %s/%s/%s"%[radius,distance,angle],covered);tested+=1
	unit.sight=400;var shot={"side":"ally","position":unit.position}
	unit.hp=0;check("death removes proof next pass",not fog._scout_covers_firing(shot,{}));unit.hp=100
	unit._dead=true;check("dead flag removes proof",not fog._scout_covers_firing(shot,{}));unit._dead=false
	unit.side="enemy";check("enemy source gives no proof",not fog._scout_covers_firing(shot,{}));unit.side="ally"
	unit.special.expansion_temporary={};check("temporary source excluded",not fog._scout_covers_firing(shot,{}));unit.special.clear()
	var site=Building.new();unit.embarked_in=site
	check("cargo excluded",not fog._scout_covers_firing(shot,{}));unit.embarked_in=null
	unit.position+=Vector2(1000,0);check("moved source rechecked",not fog._scout_covers_firing(shot,{}))
	site.position=shot.position;site.side="ai2";site.sight=300;site.weapon={};world.buildings=[site]
	check("friendly building provides proof",fog._scout_covers_firing(shot,{}))
	site.sight=100;check("range changes rechecked",not fog._scout_covers_firing(shot,{}))
	check("unknown observer conservatively rejected",not fog._scout_covers_firing({"side":"missing","position":site.position},{}))
	check("raster cases exercised",tested>=30)
	unit.free();site.free();fog.free();world.free()
	FileAccess.open(OS.get_environment("IRON_TIDE_REPORT_DIR").path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed==0 else 1)
