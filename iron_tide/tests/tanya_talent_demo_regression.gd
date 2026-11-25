extends "res://tests/commando_hero_demo_regression.gd"

func _ready() -> void:
	var output:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	swim_samples()
	damage_samples()
	chain_samples()
	target_samples()
	assault_samples()
	survival_samples()
	var viewport:=SubViewport.new();viewport.size=Vector2i(600,360)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var demo=preload("res://tests/hero_demo_text_probe.gd").new();demo.size=Vector2(600,360);viewport.add_child(demo)
	demo.show_hero("TANY")
	for track in 2:
		demo.talent.select(track);demo._select_talent()
		check(demo.levels.item_count==6,"two full six-level talent timelines")
		for rank in 6:
			demo.levels.select(rank);demo.refresh_caption();demo.playing=false
			var hashes:Array=[]
			var clipped:Array=[]
			var times:Array=[.1,1.2,2.2,3.2,4.6,5.4]
			if track==1 and rank>=3:
				check(demo.duration()==(8 if rank==3 else 48 if rank==4 else 16),"survival timeline includes its complete required branches")
				if rank==3:times.append_array([1.3,2.99,3.,5.99,6.,7.9])
				elif rank==4:times.append_array([.99,1.,1.99,2.,2.49,2.5,40.99,41.,42.,42.99,43.,44.49,44.5,45.99,46.,47.9])
				else:times.append_array([.99,1.,2.99,3.,3.99,4.,4.99,5.,7.9,8.,8.99,9.,9.99,10.,15.9])
			if track==0 and rank in [3,4]:
				check(demo.duration()==(6 if rank==3 else 16),"assault preview duration covers shock or moving-fire and stationary-C4 examples")
				times.append_array([.99,1.,1.49,1.51,2.49,2.51,3.49,3.51])
				if rank==4:times.append_array([7.9,8.,9.99,10.,12.99,13.,15.9])
			if track==0 and rank in [1,2]:
				check(demo.duration()==(12 if rank==1 else 16),"target selection preview has full boundary timeline")
				times.append_array([.99,1.,2.99,3.,3.99,4.,4.99,5.,5.99,6.,7.99,8.,11.99])
				if rank==2:times.append_array([8.99,9.,10.99,11.,13.99,14.,15.99])
			if track==0 and rank==5:
				times.append_array([.99,1.,4.99,5.,9.99,10.,60.99,61.,62.99,63.,120.99,121.,126.9])
				check(demo.duration()==127,"chain demo retains both complete sixty-second cooldowns")
			if track==1 and rank<=1:
				times=[]
				for part in (5 if rank==0 else 4):
					for clock in [.1,.99,1.01,1.19,1.21,2.01,3.01,4.19,4.21,5.9]:times.append(part*6+clock)
				check(demo.duration()==(30 if rank==0 else 24),"injury preview contains independent trigger and exclusion cases")
			if track==1 and rank==2:
				times=[]
				for part in 3:
					for clock in [.1,1.999,2.001,2.999,3.001,3.999,4.001,4.149,4.151,4.999,5.001,5.999,6.001,6.499,6.501,6.649,6.651,6.999,7.001,7.999,8.001,8.499,8.501,9.9]:times.append(part*10+clock)
				times.append(30.1)
				check(demo.duration()==30.,"swimming selector uses three complete exit timelines")
			for clock in times:
				demo.elapsed=clock;demo.refresh_preview()
				await get_tree().process_frame;await RenderingServer.frame_post_draw
				var image:=viewport.get_texture().get_image()
				if track==1 and rank>=3:
					for entry in demo.drawn_text:
						var font:=ThemeDB.fallback_font
						var bounds:=font.get_string_size(entry.text,HORIZONTAL_ALIGNMENT_LEFT,-1,14)
						if entry.position.x<0 or entry.position.x+bounds.x>demo.stage.size.x or entry.position.y-font.get_ascent(14)<0 or entry.position.y+font.get_descent(14)>demo.stage.size.y:
							clipped.append(entry.text)
				check(not image.is_empty(),"GPU full Tanya talent "+str(track)+" level "+str(rank)+" time "+str(clock))
				var stage_image:=image.get_region(Rect2i(demo.stage.get_global_rect()))
				var digest:=hash(stage_image.get_data())
				if not hashes.has(digest):hashes.append(digest)
			check(hashes.size()>=2 and demo.caption.text.begins_with("Lv.%d"%rank),"each level animates its own behavior and explains correct selection")
			if track==1 and rank>=3:check(clipped.is_empty(),"survival labels remain inside stage at every sampled boundary: "+str(clipped))
	viewport.queue_free()
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	get_tree().quit(0 if failed==0 else 1)

func swim_samples() -> void:
	const Swim=preload("res://scripts/ui/tanya_swim_demo.gd")
	check(not Swim.sample(1.999).hidden and Swim.sample(2.001).hidden,"two-second quiet swimming threshold")
	check(Swim.sample(4.001).hp==80 and Swim.sample(4.001).shield==25 and not Swim.sample(4.001).hidden,"injury pays health before two cumulative shields")
	check(Swim.sample(4.001).escape==10 and Swim.sample(4.001).swim==15,"two named shield sources are distinct")
	check(Swim.sample(6.001).hidden and not Swim.sample(6.501).hidden and Swim.sample(6.501).shield==25,"second swimming exit neither replaces nor stacks sources")
	check(is_equal_approx(Swim.sample(6.5).escape_left,.5) and is_equal_approx(Swim.sample(6.5).swim_left,1.5),"repeat exit does not extend original shield deadlines")
	check(Swim.sample(7.001).shield==15 and Swim.sample(7.001).escape==0,"baseline shield expires at three seconds")
	check(Swim.sample(8.001).shield==0 and Swim.sample(8.001).hp==80,"swim shield expires at four seconds with no healing")
	check(Swim.sample(14.001).hp==100 and Swim.sample(14.001).shield==15 and Swim.sample(14.001).escape_cd==0,"voluntary attack exit does not trigger injury shield")
	check(Swim.sample(24.001).walking and not Swim.sample(24.001).hidden and Swim.sample(24.001).shield==15 and Swim.sample(24.001).hp==100,"shore exit grants only swim shield")
	check(not Swim.sample(28.501).hidden and Swim.sample(28.501).shield==0,"land cannot spontaneously reenter swimming")
	check(Swim.sample(8.501).hidden and Swim.sample(8.501).swim_cd>10 and Swim.sample(8.501).escape_cd>25,"recloak does not erase independent shield cooldowns")
	check(Swim.sample(30.1).hp==100 and Swim.sample(30.1).shield==0,"independent examples reset at loop")

func damage_samples() -> void:
	const Injury=preload("res://scripts/ui/tanya_damage_demo.gd")
	check(Injury.sample(1.01).hp==80 and Injury.sample(1.01).shield==0 and Injury.sample(1.21).shield==10,"surviving trigger is explained in health-then-shield beats")
	check(Injury.sample(7.21).hp==90 and Injury.sample(7.21).shield==0,"ten-point loss is below the individual threshold")
	check(Injury.sample(13.21).hp==90 and Injury.sample(14.21).hp==80 and Injury.sample(15.21).hp==70 and Injury.sample(15.21).shield==0,"three small injuries never accumulate into a shield")
	check(Injury.sample(19.21).dead and Injury.sample(19.21).shield==0,"fatal baseline hit has no survival shield")
	check(Injury.sample(25.21).hp==85 and Injury.sample(25.21).shield==10,"exact fifteen-percent threshold qualifies")
	for at:float in [1.21,7.21]:
		check(is_equal_approx(Injury.sample(at,true).hp,100.0*2/3) and Injury.sample(at,true).shield==10,"dog and sniper caps preserve cumulative baseline shield "+str(at))
	check(Injury.sample(13.21,true).dead and Injury.sample(13.21,true).shield==0,"anti-hunter cannot save a twenty-health victim")
	check(Injury.sample(19.21,true).dead and Injury.sample(19.21,true).attacker=="HTNK","ordinary tank shell is not constrained by anti-hunter")
	check(Injury.sample(4.21,true).shield==0 and is_equal_approx(Injury.sample(4.21,true).hp,100.0*2/3),"cumulative shield expires without restoring lost life")

func chain_samples() -> void:
	const Chain=preload("res://scripts/ui/tanya_chain_demo.gd")
	check(Chain.sample(.99).remaining==2 and not Chain.sample(.99).charge,"chain begins with two unused transfers")
	check(Chain.sample(1).remaining==1 and Chain.sample(1).left==4 and Chain.sample(1).cooldown==60,"first transfer consumes use and starts both timers immediately")
	check(Chain.sample(4.99).charge and Chain.sample(5).secondary_dead and not Chain.sample(5).charge,"chain explodes after four complete seconds")
	check(Chain.sample(10).remaining==1 and not Chain.sample(10).charge and Chain.sample(10).cooldown==51,"another demolition during cooldown cannot transfer or spend another use")
	check(Chain.sample(60.99).remaining==1 and Chain.sample(61).remaining==0 and Chain.sample(61).cooldown==60,"second transfer waits full sixty seconds and consumes last use")
	check(Chain.sample(62.99).charge and Chain.sample(63).disarmed and not Chain.sample(63).secondary_dead,"engineer cancels pending second explosion and preserves building")
	check(Chain.sample(63).remaining==0 and Chain.sample(63).cooldown==58,"engineer disarm refunds neither count nor cooldown")
	check(Chain.sample(121).cooldown==0 and Chain.sample(121).remaining==0 and not Chain.sample(121).charge,"third eligible demolition after cooldown cannot exceed per-match quota")

func target_samples() -> void:
	const Target=preload("res://scripts/ui/tanya_target_demo.gd")
	check(not Target.sample(1,0).visible and Target.sample(1,2).visible,"ground target becomes visible only after entering two cells")
	check(Target.sample(1,3.99).visible and not Target.sample(1,4).visible and Target.sample(1,5).visible,"solid wall blocks detection until removed")
	check(not Target.sample(1,8).visible and not Target.sample(1,2).sub_visible,"leaving range conceals ground target; nearby submarine never exposed")
	check(Target.sample(2,2.99).extra==0 and Target.sample(2,3).extra==1,"only third normal volley adds first side shot")
	check(Target.sample(2,5.99).extra==1 and Target.sample(2,6).extra==2,"side shot does not count as another normal volley")
	check(Target.sample(2,11).rounds==3 and Target.sample(2,14).rounds==6 and Target.sample(2,14).extra==0,"single-target case never redirects an extra shot onto primary")

func assault_samples() -> void:
	const Assault=preload("res://scripts/ui/tanya_assault_demo.gd")
	check(not Assault.sample(3,.99).destroyed and Assault.sample(3,1).destroyed,"native primary demolition precedes shock damage")
	check(Assault.sample(3,1).infantry_hp==40 and Assault.sample(3,1).neighbor_hp==100 and Assault.sample(3,1).outside_hp==100,"shock affects nearby infantry but neither nearby building nor distant infantry")
	check(Assault.sample(4,.99).speed==100 and Assault.sample(4,1).speed==70 and Assault.sample(4,1.5).speed==100,"speed restriction applies only during firing animation")
	var slow_delta:float=Assault.sample(4,1.4).distance-Assault.sample(4,1.1).distance
	var fast_delta:float=Assault.sample(4,.4).distance-Assault.sample(4,.1).distance
	check(is_equal_approx(slow_delta,fast_delta*.7),"rendered route distance actually advances at seventy percent while firing")
	check(Assault.sample(4,3.1).rounds==3 and Assault.sample(4,7.9).rounds==3,"moving fire timeline does not insert extra volleys")
	check(Assault.sample(4,10).installing and Assault.sample(4,10).distance==Assault.sample(4,12.99).distance and Assault.sample(4,12).speed==0,"C4 installation holds position rather than moving with the gun animation")
	check(not Assault.sample(4,13).installing and Assault.sample(4,14).distance>Assault.sample(4,13).distance,"leaving C4 installation restores movement")

func survival_samples() -> void:
	const Survival=preload("res://scripts/ui/tanya_survival_demo.gd")
	check(Survival.sample(3,2).gap==48 and Survival.sample(3,7).gap==48,"vehicle stops at collision rather than crossing immune infantry")
	check(Survival.sample(3,2.99).hp==100 and Survival.sample(3,3).hp==80 and Survival.sample(3,3).shield==10,"crush immunity still allows cannon damage and cumulative injury shield")
	check(Survival.sample(3,6).shield==0 and Survival.sample(3,6).hp==80,"cannon-triggered shield expires without undoing damage")
	check(Survival.sample(4,1).flash and Survival.sample(4,2.49).flash and not Survival.sample(4,2.5).flash,"flash silences infantry for exactly one and a half seconds")
	check(Survival.sample(4,2).hp==15 and Survival.sample(4,2).flash,"in-flight cannon still lands during flash")
	check(Survival.sample(4,2.19).hp==15 and Survival.sample(4,2.2).hp==10 and Survival.sample(4,2.2).flash,"vehicle can fire another shell during infantry silence")
	check(Survival.sample(4,41).cooldown==0 and not Survival.sample(4,41).flash and Survival.sample(4,41).hp==9,"cooldown alone cannot retrigger while health never recovered")
	check(Survival.sample(4,42).hp==44 and Survival.sample(4,43).hp==24 and Survival.sample(4,43).flash and Survival.sample(4,43).shield==10,"explicit external heal rearms flash and later substantial hit grants cumulative shield")
	check(Survival.sample(4,46).shield==0 and not Survival.sample(4,46).flash,"second flash and injury shield expire independently")
	check(Survival.sample(5,1).hp==1 and Survival.sample(5,1).shield==10 and Survival.sample(5,1).hidden,"last stand keeps one life plus the baseline shield")
	check(not Survival.sample(5,3).hidden and Survival.sample(5,3).shield==10 and Survival.sample(5,4).shield==0,"two-second cloak and three-second injury shield have separate expirations")
	check(Survival.sample(5,5).dead and Survival.sample(5,5).used,"later lethal hit does not grant another rescue")
	check(Survival.sample(5,9.99).hidden and Survival.sample(5,10).dead and Survival.sample(5,10).shield==0,"range damage can kill during cloak despite ten-point shield")
