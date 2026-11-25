extends Node
const Timeline=preload("res://scripts/ui/boris_control_demo.gd")
const Radio=preload("res://scripts/units/boris_radio.gd")
const Support=preload("res://scripts/ui/boris_support_demo.gd")
const Lethal=preload("res://scripts/ui/boris_lethal_demo.gd")
var checks:Array=[]
var failed:=0

func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok:failed+=1;push_error(label)

func _ready() -> void:
	var output:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	boundary_samples()
	check(not Timeline.sample(.99).controlled,"no timed control before its application")
	check(Timeline.sample(1).left==2 and Timeline.sample(1).normal_left==4,"same application gives two seconds to hero and four to ordinary unit")
	check(Timeline.sample(2.99).controlled and not Timeline.sample(3).controlled and Timeline.sample(3).normal_left==2,"hero resumes exactly at two seconds while ordinary remains controlled")
	check(Timeline.sample(5).normal_left==0,"ordinary control expires after full four seconds")
	check(Timeline.sample(6).left==4 and Timeline.sample(7).left==3 and Timeline.sample(7).new_left==1,"second scenario retains existing three seconds when incoming shortened control is one second")
	check(Timeline.sample(9.99).controlled and not Timeline.sample(10).controlled,"additional shorter application never shortens original expiry")
	check(not Timeline.sample(12.99).maintained and Timeline.sample(13).maintained,"maintained ray begins only at the real channel start")
	check(Timeline.sample(15.1).controlled and Timeline.sample(16.99).controlled,"maintained freeze survives beyond the timed resistance example")
	check(not Timeline.sample(17).controlled,"stopping maintained ray releases freeze")
	var saved:=var_to_bytes(MetaProgress.academy)
	var viewport:=SubViewport.new();viewport.size=Vector2i(650,360);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var demo=preload("res://tests/hero_demo_text_probe.gd").new();demo.size=Vector2(650,360);viewport.add_child(demo)
	demo.show_hero("BORIS");demo.talent.select(1);demo._select_talent();demo.playing=false
	for rank in 6:
		demo.levels.select(rank);demo.refresh_caption()
		check(demo.caption.text.contains(Radio.DEFENSE[rank]),"radio description remains mapped to rank "+str(rank))
		check(demo.duration()==(Lethal.duration(rank) if rank in [1,5] else Support.duration(rank) if rank in [3,4] else 18 if rank==2 else 6),"radio timeline length "+str(rank))
		var times:Array=[.1,1.1,2.1,2.99,3.1,4.1,5.1]
		if rank==2:times.append_array([6.,7.,9.99,10.,12.,13.,15.1,16.99,17.,17.99])
		if rank in [1,5]:
			for part in (3 if rank==1 else 4):
				for t:float in [.99,1.,1.3,2.29,2.3,2.49,2.5,3.,3.99,4.,5.9]:times.append(part*6+t)
		if rank==3:
			for part in 4:
				for t:float in [.99,1.,1.99,2.,2.99,3.,4.,4.99,5.,6.,12.99,13.,13.9]:times.append(part*14+t)
		if rank==4:times.append_array([.99,1.,1.29,1.3,1.99,2.,3.99,4.,4.99,5.,20.99,21.,24.99,25.,25.9])
		var hashes:Array=[]
		var clipped:Array=[]
		for t in times:
			demo.elapsed=t;demo.refresh_preview()
			await get_tree().process_frame;await RenderingServer.frame_post_draw
			var picture:=viewport.get_texture().get_image()
			if rank in [1,3,4,5]:
				var offset_x:=maxf(0,(demo.stage.size.x-540)*.5)
				for entry in demo.drawn_text:
					var font:=ThemeDB.fallback_font
					var size:=font.get_string_size(entry.text,HORIZONTAL_ALIGNMENT_LEFT,-1,14)
					if entry.position.x+offset_x<0 or entry.position.x+offset_x+size.x>demo.stage.size.x or entry.position.y-font.get_ascent(14)<0 or entry.position.y+font.get_descent(14)>demo.stage.size.y:clipped.append(entry.text)
			check(not picture.is_empty(),"GPU radio rank "+str(rank)+" at "+str(t))
			var digest:=hash(picture.get_region(Rect2i(demo.stage.get_global_rect())).get_data())
			if not hashes.has(digest):hashes.append(digest)
		check(hashes.size()>=3,"radio rank displays its distinct phases "+str(rank))
		if rank in [1,3,4,5]:check(clipped.is_empty(),"new radio branch labels remain in visible stage: "+str(clipped))
	check(saved==var_to_bytes(MetaProgress.academy),"preview selection and playback do not change academy progression")
	viewport.free()
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	get_tree().quit(0 if failed==0 else 1)

func boundary_samples() -> void:
	check(Lethal.sample(1,.99).hp==100 and Lethal.sample(1,1).hp==50 and Lethal.sample(1,4).dead,"ordinary blast cap still permits the next hit to kill")
	check(Lethal.sample(1,6).hp==40 and Lethal.sample(1,7).dead,"low-health lining example dies despite cap")
	check(Lethal.sample(1,13).mig and Lethal.sample(1,13).dead,"MiG has no inherited blast lining")
	check(Support.sample(3,1).dropped and not Support.sample(3,2.99).pickup and Support.sample(3,3).pickup,"bomb release alone does not create supply before exit")
	check(Support.sample(3,4.99).hp==60 and Support.sample(3,4.99).pickup and Support.sample(3,5).hp==75 and not Support.sample(3,5).pickup,"owner contact heals fifteen and consumes supply")
	check(Support.sample(3,6).picked and not Support.sample(3,6).pickup,"later same-wing exit cannot replace consumed supply")
	check(Support.sample(3,19).hp==100 and Support.sample(3,19).pickup and Support.sample(3,26.99).pickup and not Support.sample(3,27).pickup,"full-health contact preserves supply until ten-second expiry")
	check(not Support.sample(3,31).dropped and not Support.sample(3,31).pickup,"aborted flight without payload release leaves no supply")
	check(Support.sample(3,44).destroyed and not Support.sample(3,45).pickup,"shot-down bomber cannot generate exit supply")
	check(Support.sample(4,1).shields==[10,10,0] and Support.sample(4,1.3).shields==[10,10,0],"canceling call preserves shields on only nearest two soldiers")
	check(Support.sample(4,2).cooldown==19 and Support.sample(4,4).shields==[5,10,0] and Support.sample(4,5).shields==[0,0,0],"second call cannot reset shield amounts or original expiration")
	check(Support.sample(4,20.99).shields==[0,0,0] and Support.sample(4,21).shields==[10,10,0] and Support.sample(4,25).shields==[0,0,0],"cover becomes available at full twenty-second interval and expires four seconds later")
	check(not Lethal.sample(5,.99).warning and Lethal.sample(5,1).dead and Lethal.sample(5,1).warning,"combat death starts legal fixed warning without revival")
	check(Lethal.sample(5,2.49).warning and Lethal.sample(5,2.49).victim_hp==200 and Lethal.sample(5,2.5).blast and Lethal.sample(5,2.5).victim_hp==50,"fixed warning lasts one and a half seconds before example 150 damage")
	check(Lethal.sample(5,2.3).offset>60,"original attacker leaves the drawn blast radius before impact")
	for part in [1,2,3]:
		check(Lethal.sample(5,part*6+1).dead and not Lethal.sample(5,part*6+1).warning and not Lethal.sample(5,part*6+2.5).blast,"illegal last source never schedules a blast: "+str(part))
