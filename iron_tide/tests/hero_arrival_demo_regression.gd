extends Node
const Demo=preload("res://scripts/ui/hero_arrival_demo.gd")
var checks:Array=[]
var failed:=0

func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok:failed+=1;push_error(label)

func _ready() -> void:
	var output:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	var before:=JSON.stringify([MetaProgress.currency,MetaProgress.academy,MetaProgress.stats])
	var viewport:=SubViewport.new();viewport.size=Vector2i(700,600);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var demo=preload("res://tests/hero_arrival_text_probe.gd").new();demo.size=Vector2(540,380);viewport.add_child(demo)
	for id:String in ["ORCA","TTNK"]:
		demo.show_hero(id);demo.playing=false
		var hashes:Array=[]
		for t:float in [0,2,4,5,6,7,8,9,10,11,12,13,14,15,16,18,19,20,21,23,25,27]:
			if t>=demo.duration():continue
			demo.playback.user_seek(t)
			await get_tree().process_frame;await RenderingServer.frame_post_draw
			check(not demo.playing and demo.status.text==Demo.sample(id,t).phase,"seek pauses at correct visible event "+id+str(t))
			for row in demo.drawn_text:
				var extent:=ThemeDB.fallback_font.get_string_size(row.text,HORIZONTAL_ALIGNMENT_LEFT,-1,14)
				check(row.at.x>=0 and row.at.x+extent.x<=demo.stage.size.x and row.at.y+ThemeDB.fallback_font.get_descent(14)<=demo.stage.size.y,"drawn label fits stage "+id+str(t)+row.text)
			var picture:=viewport.get_texture().get_image().get_region(Rect2i(demo.stage.get_global_rect()))
			var hash:=picture.get_data().hex_encode().sha256_text()
			if not hash in hashes:hashes.append(hash)
		check(hashes.size()>=6,"timeline renders distinct production/save/death/new-match states "+id)
		demo.playback.seek(demo.duration());check(demo.elapsed>demo.duration()-.1,"right endpoint stays in final match "+id)
	var plane:=Demo.sample("ORCA",2)
	check(plane.count==1 and plane.alive and plane.slots==1,"first plane retains ordinary dock owner and separate living hero")
	check(Demo.sample("ORCA",4).count==1 and Demo.sample("ORCA",7).alive,"duplicate and restore preserve original plane and hero")
	check(Demo.sample("ORCA",15).count==4 and Demo.sample("ORCA",15).dead,"four ordinary airport slots remain while gift stays dead")
	check(Demo.sample("ORCA",20).count==1 and Demo.sample("ORCA",20).alive,"new match alone renews Peregrine gift")
	check(Demo.sample("TTNK",6).count==2 and not Demo.sample("TTNK",6).gifted,"two-product save does not pregrant LeiZhu")
	check(Demo.sample("TTNK",8).count==3 and Demo.sample("TTNK",8).alive,"third tank retained with extra living LeiZhu")
	check(Demo.sample("TTNK",10).count==3 and Demo.sample("TTNK",12).alive,"duplicate and postgift restore preserve third milestone")
	check(Demo.sample("TTNK",16).count==4 and Demo.sample("TTNK",16).dead,"fourth tank does not replace dead LeiZhu")
	check(Demo.sample("TTNK",25).count==3 and Demo.sample("TTNK",25).alive,"next match requires third product again")
	demo.free()
	var panel=preload("res://scripts/ui/expansion_contract_panel.gd").new();panel.size=Vector2(650,550);viewport.add_child(panel)
	for id:String in ["ORCA","TTNK","TANY","BORIS"]:
		panel.refresh(id)
		var toggle:Button=panel.find_child("ArrivalDemoToggle",true,false)
		if id in ["ORCA","TTNK"]:
			check(toggle!=null and panel.find_child("HeroArrivalDemo",true,false)==null,"arrival preview is available without purchase and lazy "+id)
			toggle.button_pressed=true
			await get_tree().process_frame
			var child=panel.find_child("HeroArrivalDemo",true,false)
			check(child!=null and child.hero_id==id and child.is_processing(),"actual toggle opens matching running preview "+id)
			toggle.button_pressed=false;await get_tree().process_frame
			check(not child.is_processing(),"collapsed preview stops processing "+id)
			toggle.button_pressed=true
			check(panel.find_child("HeroArrivalDemo",true,false)==child,"reopening reuses preview "+id)
		else:check(toggle==null,"unrelated hero has no aircraft/tank production illustration "+id)
	check(JSON.stringify([MetaProgress.currency,MetaProgress.academy,MetaProgress.stats])==before,"opening playing seeking and switching previews preserve persistent progression")
	viewport.free();await get_tree().process_frame
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0},"  "))
	get_tree().quit(0 if failed==0 else 1)
