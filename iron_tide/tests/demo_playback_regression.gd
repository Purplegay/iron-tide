extends "res://tests/native_demo_regression.gd"
const Playback=preload("res://scripts/ui/demo_playback.gd")

func exercise(mode:String) -> void:
	super.exercise(mode)
	if mode==MatchRules.RA2:return
	var before:=JSON.stringify(MetaProgress.to_dict())
	var demo:=Demo.new();add_child(demo);demo.configure("DOG",2)
	audit(demo.playback,demo.stage,&"elapsed",1.0)
	demo.playback.speed.item_selected.emit(0)
	demo.playback.seek(2.25);demo.stage.playing=false
	demo.select_rank(3)
	check(demo.stage.elapsed==2.25 and not demo.stage.playing and demo.stage.playback_speed==0.25,"native level change preserves time pause and speed")
	demo.stage.playing=true;demo.levels.item_selected.emit(1)
	check(demo.stage.elapsed==2.25 and demo.stage.playing and demo.playback.timeline.value==2.25,"native playing level switch stays at same second")
	demo.restart();check(demo.stage.elapsed==0 and demo.stage.playing,"explicit replay still resets")
	demo.free()
	var long_demo:=Demo.new();add_child(long_demo);long_demo.configure("IVAN",0)
	audit(long_demo.playback,long_demo.stage,&"elapsed",long_demo.stage.time_rate())
	long_demo.free()
	var stock=preload("res://scripts/ui/unit_showcase.gd").new();add_child(stock);stock.show_unit("MTNK")
	stock.playing=false;stock.playback_speed=0.25;stock.age=0;stock._process(0.4)
	check(is_equal_approx(stock.age,0.4),"ordinary model rotation is unaffected by demo playback settings")
	stock.free()
	var gallery=preload("res://scripts/ui/faction_card_gallery.gd").new();add_child(gallery)
	var card_controls:Control=find_controls(gallery)
	audit(card_controls,gallery.stage,&"elapsed",1.0)
	for i in gallery.card_ids().size():
		gallery.select_card(i,3);card_controls.sync()
		check(is_equal_approx(card_controls.timeline.max_value,gallery.stage.duration),"card timeline follows duration "+str(i))
		card_controls.seek(gallery.stage.duration)
		check(gallery.stage.elapsed<gallery.stage.duration and gallery.stage.elapsed>gallery.stage.duration-0.01,"card final frame does not wrap "+str(i))
		card_controls.seek(1.25);gallery.stage.playing=false
		gallery.levels.item_selected.emit(0)
		check(gallery.stage.elapsed==1.25 and not gallery.stage.playing and gallery.stage.preview_rank==0,"card rank selection preserves paused second "+str(i))
	gallery.select_card(gallery.ids.find("ap_twin"),3);gallery.stage.elapsed=6.0;gallery.stage.playing=true
	gallery.levels.item_selected.emit(0)
	check(not gallery.stage.playing and gallery.stage.elapsed>gallery.stage.duration-0.01 and gallery.stage.elapsed<gallery.stage.duration,"shorter card rank clamps to final frame and pauses")
	check(is_equal_approx(card_controls.timeline.max_value,gallery.stage.duration),"shorter rank timeline updates immediately")
	gallery.select_card(gallery.ids.find("ap_twin"),0)
	check(gallery.stage.elapsed==0 and gallery.stage.playing,"card explicit replay still resets")
	gallery.free()
	var hero=preload("res://scripts/ui/hero_talent_demo.gd").new();add_child(hero);hero.show_hero("E1")
	audit(hero.playback,hero,&"elapsed",1.0)
	hero.playback.seek(2.25);hero.playing=false
	hero.levels.select(2);hero.levels.item_selected.emit(2)
	check(hero.elapsed==0 and hero.playing and hero.caption.text.contains("随队") and hero.playback.timeline.value==0,"hero level switch restarts from beginning")
	hero.playback.speed.item_selected.emit(0);hero.elapsed=2.5
	hero.levels.select(1);hero.levels.item_selected.emit(1)
	check(hero.elapsed==0 and hero.playing and hero.playback_speed==0.25,"playing hero rank change restarts but preserves slow motion")
	hero.elapsed=2.5;hero.playing=false;hero.talent.select(1);hero.talent.item_selected.emit(1)
	check(hero.elapsed==0 and hero.playing and hero.pause_button.text=="暂停","hero talent change restarts paused preview")
	hero.show_hero("HTNK");hero.elapsed=3;hero.talent.select(0);hero.talent.item_selected.emit(0)
	hero.levels.select(1);hero.levels.item_selected.emit(1)
	check(hero.elapsed==0 and hero.playing and hero.revival_status.text.contains("15.0"),"hero revival rank starts full countdown")
	hero.restart();check(hero.elapsed==0 and hero.playing,"hero explicit replay still resets")
	hero.free()
	var meta=preload("res://scripts/screens/meta_screen.gd").new();add_child(meta)
	meta._show_talent_demo("MTNK",Unit.YRTalents.REVERSE,2)
	var showcase:Control=meta.find_child("Preview",true,false)
	var controls:Control=find_controls(meta.get_node("TalentDemo"))
	check(showcase!=null and controls!=null,"existing dedicated talent modal has playback controls")
	audit(controls,showcase,&"age",1.0)
	controls.seek(1.0)
	check(showcase.actor._anim==1.0,"seeking updates real showcase pose immediately")
	var picker:OptionButton=showcase.get_parent().get_child(showcase.get_index()+1)
	showcase.playing=false;picker.select(3);picker.item_selected.emit(3)
	check(showcase.age==1.0 and not showcase.playing and showcase.rank==3 and showcase.actor._anim==1.0,"dedicated talent level switch preserves pose and pause")
	meta.free()
	check(JSON.stringify(MetaProgress.to_dict())==before,"all playback controls remain read only")

func find_controls(node:Node):
	if node.get_script()==Playback:return node
	for child in node.get_children():
		var found=find_controls(child)
		if found!=null:return found
	return null

func audit(controls:Control,player:Control,clock:StringName,base_rate:float) -> void:
	for i in Playback.RATES.size():
		controls.speed.item_selected.emit(i);controls.seek(0);player.playing=true
		player._process(0.4)
		check(is_equal_approx(float(player.get(clock)),0.4*Playback.RATES[i]*base_rate),"slow motion advances presentation clock "+str(i))
	controls.seek(1.25);controls.sync()
	check(is_equal_approx(float(player.get(clock)),1.25) and is_equal_approx(controls.timeline.value,1.25),"slider seeks and synchronizes timestamp")
	player.playing=true;controls.begin_scrub();controls.seek(2.0);player._process(0.5)
	check(not player.playing and float(player.get(clock))==2.0,"drag freezes playback")
	controls.end_scrub(true);player._process(0.5)
	check(not player.playing and float(player.get(clock))==2.0,"release stays paused at dragged frame")
	check(controls.pause_button.text=="继续","scrubbing updates continue button immediately")
	controls.pause_button.pressed.emit();player._process(0.4)
	check(player.playing and float(player.get(clock))>2.0,"explicit continue resumes playback")
	player.playing=true;controls.timeline.value=1.5;player._process(0.4)
	check(not player.playing and float(player.get(clock))==1.5,"timeline value change also pauses click and keyboard seek")
	player.playing=true;controls.begin_scrub();controls.end_scrub(false)
	check(not player.playing,"clicking current position without movement also stays paused")
	player.playing=false;controls.begin_scrub();controls.seek(0.5);controls.end_scrub(true)
	check(not player.playing,"release preserves paused demo")
	controls.seek(999)
	check(float(player.get(clock))<float(controls.length.call()),"seek clamps before loop endpoint")
	controls.seek(-2);check(float(player.get(clock))==0,"negative seek clamps to start")
