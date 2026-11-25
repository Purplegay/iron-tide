extends Node
const Timeline=preload("res://scripts/ui/hero_combo_timeline.gd")
var checks:Array=[]
var failed:=0
func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok:failed+=1;push_error(label)

func _ready() -> void:
	var output:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	var before:=MetaProgress.to_dict().duplicate(true)
	var viewport:=SubViewport.new();viewport.size=Vector2i(700,750);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var demo=preload("res://tests/hero_combo_text_probe.gd").new();demo.size=Vector2(540,560);viewport.add_child(demo)
	for id:String in ["ORCA","BORIS","TTNK"]:
		demo.show_hero(id);demo.playing=false
		var hashes:Array=[]
		var times:Array=[0.,1.,2.,3.,4.,5.,6.,7.,8.,9.,10.,11.,12.,13.,15.,demo.duration()-.01]
		if id=="ORCA":
			var fill:=Timeline.first_fill()
			times.append_array([fill-.01,fill+.01,fill+5.01,fill+8.01,fill+35.99,fill+36.01,fill+38.01,fill+41.01])
		for t:float in times:
			if t>=demo.duration():continue
			demo.playback.user_seek(t);await get_tree().process_frame;await RenderingServer.frame_post_draw
			check(demo.caption.text==Timeline.sample(id,t).phase and not demo.playing,"actual caption follows paused combined timeline "+id+str(t))
			for row in demo.drawn_text:
				var size:=ThemeDB.fallback_font.get_string_size(row.text,HORIZONTAL_ALIGNMENT_LEFT,-1,14)
				check(row.at.x+size.x<=demo.stage.size.x and row.at.y+ThemeDB.fallback_font.get_descent(14)<=demo.stage.size.y,"stage text is not clipped "+id+row.text)
			check(demo.metrics.get_visible_line_count()>=demo.metrics.get_line_count(),"all combined metrics remain visible "+id+str(t))
			var digest:=viewport.get_texture().get_image().get_data().hex_encode().sha256_text()
			if not digest in hashes:hashes.append(digest)
		check(hashes.size()>8,"combined actions produce distinct rendered states "+id)
	var fill:=Timeline.first_fill()
	for at:float in [3.,5.]:
		check(absf(Timeline.peregrine(at-.00001).progress-Timeline.peregrine(at+.00001).progress)<.00001,"airport arrival/departure preserves reload percentage "+str(at))
	check(Timeline.peregrine(fill-.001).ammo==4 and Timeline.peregrine(fill+.001).ammo==5,"first accelerated refill completes on calculated boundary")
	check(Timeline.peregrine(fill+.001).hp==65 and Timeline.peregrine(fill+.001).cycle==1,"full refill alone adds signature heal and cycle")
	check(Timeline.peregrine(fill+5.01).ammo==0 and Timeline.peregrine(fill+5.01).speed==1.2,"five-shot sequence empties before next refill and enables surplus speed")
	check(Timeline.peregrine(fill+8.01).ammo==1 and Timeline.peregrine(fill+8.01).hp==65 and Timeline.peregrine(fill+8.01).cycle==1,"partial refill neither heals nor grants another shield cycle")
	check(Timeline.peregrine(fill+36.01).hp==70 and Timeline.peregrine(fill+36.01).cycle==2,"second real full cycle heals again")
	check(Timeline.peregrine(fill+38.01).maintenance_shield==20 and Timeline.peregrine(fill+40.99).hp==70,"landed maintenance gets independent shield and waits three quiet seconds")
	check(is_equal_approx(Timeline.peregrine(fill+42).hp,72),"maintenance then heals two percent per second")
	var wave:=Timeline.boris(6.1)
	check(wave.main==4 and wave.secondary==2 and wave.stamps==0 and is_equal_approx(wave.damage,1.12) and is_equal_approx(wave.radius,1.3),"one three-stamp snapshot gives all six rank-zero gains")
	check(Timeline.boris(11.5).main==0 and Timeline.boris(11.5).occupied and Timeline.boris(11.5).native_cd==Timeline.AirSupport.recharge(),"departed main group cannot start recharge before side group")
	check(Timeline.boris(13.5).native_cd==Timeline.AirSupport.recharge()-.5 and Timeline.boris(13.5).w_cd==48.5,"native and W cooldowns keep independent origins")
	check(Timeline.boris(14).relay_grants==1 and Timeline.boris(14).supplies==1 and Timeline.boris(14).hp==75,"whole wing grants only one relay and one collected supply")
	check(Timeline.leizhu(2.1).stolen==10 and Timeline.leizhu(3.1).recycled==4 and Timeline.leizhu(3.1).hp==90,"steal and electric recovery have distinct damage accounting")
	check(Timeline.leizhu(4.1).arc and Timeline.leizhu(4.1).charge==0 and Timeline.leizhu(6).charge==0,"third primary discharges once and DOT does not refill charges")
	check(Timeline.leizhu(5.1).recycled==0 and Timeline.leizhu(5.1).ally_hp==20,"transferred four damage consumes old recovery shield without generating a new one")
	check(Timeline.leizhu(8.9).court and not Timeline.leizhu(9.1).court and Timeline.leizhu(9.1).power==0 and not Timeline.leizhu(9.1).divert,"shutdown clears still-live court and stops supply and diversion together")
	check(Timeline.leizhu(12.1).hp==20 and Timeline.leizhu(12.1).power==100 and Timeline.leizhu(12.1).divert and not Timeline.leizhu(12.1).court and Timeline.leizhu(12.1).w_cd>0,"survival resumes passive services without reopening W")
	demo.free()
	var panel=preload("res://scripts/ui/expansion_contract_panel.gd").new();panel.size=Vector2(650,700);viewport.add_child(panel)
	for id:String in ["ORCA","BORIS","TTNK","TANY"]:
		panel.refresh(id)
		var toggle:Button=panel.find_child("ComboDemoToggle",true,false)
		if id=="TANY":check(toggle==null,"Tanya has no unrelated three-hero combination");continue
		check(toggle!=null and panel.find_child("HeroComboDemo",true,false)==null,"combined preview is available and lazy "+id)
		toggle.button_pressed=true;await get_tree().process_frame
		var child=panel.find_child("HeroComboDemo",true,false)
		check(child.hero_id==id and child.is_processing(),"real button opens matching combined timeline "+id)
		toggle.button_pressed=false;await get_tree().process_frame
		check(not child.is_processing(),"collapsed timeline stops processing "+id)
	check(MetaProgress.to_dict()==before,"all combinations preserve persistent profile")
	viewport.free();await get_tree().process_frame
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0},"  "))
	get_tree().quit(0 if failed==0 else 1)
