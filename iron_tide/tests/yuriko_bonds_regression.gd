extends Node

const Book=preload("res://scripts/units/yuriko_school.gd")
const Bonds=preload("res://scripts/units/yuriko_bonds.gd")
const Field=preload("res://scripts/expedition/yuriko_field.gd")
const Missions=preload("res://scripts/expedition/field_missions.gd")
const Psi=preload("res://scripts/units/yuriko.gd")
var checks:=0
var failed:=0

func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):
		get_tree().quit(2)
		return
	call_deferred("run")

func check(ok:bool,why:String) -> bool:
	checks+=1
	if not ok:failed+=1
	print("PASS " if ok else "FAIL ",why)
	return ok

func open_battle(map:String,fresh:=true,stage:=1):
	if fresh and not check(Expedition.start("美国","",121) and Expedition.choose(0),"prepare expedition"):return null
	var plan:Dictionary=Expedition.state.duplicate(true)
	if fresh:plan.stage=stage
	Expedition.ready(plan)
	plan.routes[0].map=map
	for n in range(1,2000):
		if Missions.candidate(n,int(plan.stage),plan.routes[0],plan.cycle)=="":
			plan.seed=n
			break
	if not check(Expedition.commit(plan) and Expedition.launch(0),"launch "+map):return null
	var screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	return screen

func recover(screen) -> void:
	var field=screen.expedition_runtime.field_ops
	if field.data.has("school_finds"):
		for kind:String in field.data.school_finds:
			var item:Dictionary=field.data.school_finds[kind]
			check(screen.find_child("SchoolFind_"+kind,true,false)!=null,"dedicated pink action for "+kind)
			screen.battle.spawn_unit("E1","ally",item.position)
			field.tick(.1)
			check(item.taken,"ground team recovers "+kind)
		for job in field.data.objectives:
			if job.get("hero_lead","")=="YURIKO":
				screen.battle.spawn_unit("E1","ally",job.position)
				field.tick(21.0)
		return
	for job in field.data.objectives:
		if not job.has("school_gift"):continue
		screen.battle.spawn_unit("E1","ally",job.position)
		field.tick(21.0)
		check(job.done and not job.failed,"ordinary soldier secures "+str(job.school_gift))
		return
	check(false,"recoverable field objective")

func finish(screen,win:bool) -> void:
	screen.battle.end_battle(win,false,true)
	screen.free()

func read_chapter(index:int) -> void:
	var ep:Dictionary=Book.episodes[index]
	for step in 32:
		if MetaProgress.yuriko_school.get("read",{}).has(ep.id):break
		if not Book.advance(ep,0 if Book.choosing(ep) else -1):break
	check(MetaProgress.yuriko_school.get("read",{}).has(ep.id),"read earned page "+str(index+1))

func button(root:Node,prefix:String) -> Button:
	for b:Button in root.find_children("*","Button",true,false):
		if b.text.begins_with(prefix) and not b.disabled:return b
	return null

func conclude() -> void:
	print("YURIKO BONDS checks=%d failed=%d"%[checks,failed])
	get_tree().quit(1 if failed else 0)

func run() -> void:
	get_tree().current_scene=null
	check(Book.commit({}),"begin isolated profile")
	check(Field.encounter({"research":{"intel":1}},"exp_plain") and Field.encounter({"yuriko_recruited":true},"exp_plain"),"intel and recruited expeditions reveal first meeting inland")
	for kind:String in ["diary","fragment"]:
		var payload:Dictionary={"diary":{"taken":kind=="diary","gift":"cola"},"fragment":{"taken":kind=="fragment","fragment":1}}
		var receipt_run:Dictionary={"id":"single_find","stage":1}
		Bonds.settle(receipt_run,{"school_finds":payload},{})
		var reward:Dictionary=receipt_run.school_deliveries["single_find/1"]
		check(reward.has("fragment")== (kind=="fragment") and reward.has("daily_diaries")== (kind=="diary"),"only recovered item settles: "+kind)
	var base=load("res://scenes/meta.tscn").instantiate()
	add_child(base)
	var entry:Button=base.find_child("YurikoBaseTab",true,false)
	check(entry.disabled and entry.text=="？？？","base entry conceals initial discovery")
	base.free()
	var screen=open_battle("exp_plain")
	if screen==null:conclude();return
	check(not screen.expedition_runtime.field_ops.data.has("shelter_at"),"other map has no shelter")
	var initial_field=screen.expedition_runtime.field_ops
	for both_taken in [false,true]:
		initial_field.data.school_finds={"diary":{"taken":true,"gift":"cola"},"fragment":{"taken":both_taken,"fragment":1}}
		Field.prepare_finds(initial_field,{"stage":5})
		check(initial_field.data.school_finds.keys()==["diary"],"old double marker keeps collected diary")
		var old_run:={"id":"restore","stage":5}
		Bonds.settle(old_run,initial_field.data,{})
		var earned:Dictionary=old_run.school_deliveries["restore/5"]
		check(earned.get("daily_diaries",0)==1 and (int(earned.get("fragment",0))>0)==both_taken,"restore pays exactly what was collected")
	initial_field.data.erase("school_extra_fragment")
	initial_field.data.erase("school_finds")
	Field.setup(initial_field,{"route":{"map":"exp_plain"},"research":{"intel":1}},true)
	check(initial_field.data.has("shelter_at"),"restore adds inland encounter for researched intel")
	initial_field.data.erase("shelter_at")
	recover(screen)
	finish(screen,true)
	check(not Book.met() and not Book.available(Bonds.stories[0]) and Bonds.give("cola")=="","ordinary team banks finds before meeting her")
	check(MetaProgress.yuriko_school.get("gifts",{}).get("cola",0)==1 and MetaProgress.yuriko_school.get("fragments",{}).is_empty(),"diary victory awards cola only")
	for outcome in ["no visit","loss","win"]:
		screen=open_battle("yr_oceansid")
		if screen==null:conclude();return
		var field=screen.expedition_runtime.field_ops
		if not check(field.data.has("shelter_at"),"reachable shelter generated"):conclude();return
		check(field.markers().any(func(m):return m.position==field.data.shelter_at and m.color==Field.PINK) and field.summary().contains("雨棚") and screen.find_child("YurikoShelter",true,false).is_visible_in_tree(),"pink shelter pin and visible HUD shortcut before discovery")
		if outcome!="no visit":
			screen.battle.spawn_unit("E1","ally",field.data.shelter_at)
			field.tick(.1)
			check(field.data.get("shelter_heard",false) and Music.stage=="yuriko_tension" and Music.current_title()=="YurikoTensionb","approaching shelter triggers second recording")
			recover(screen)
		if outcome=="win":
			var saved:=Expedition.checkpoint(screen.battle)
			if not check(saved,"save the encounter before its victory "+Expedition.error):conclude();return
			var invalid:Dictionary=Expedition.state.checkpoint.duplicate(true)
			var held:Dictionary=invalid.context.death_sight.ally
			if not held.is_empty():
				held[held.keys()[0]]=20.1
				check(BattleSaves.validate(invalid)=="迷雾时间无效","expedition intel still rejects invalid durations")
			screen.free()
			if not check(Expedition.load_run() and Expedition.prepare_battle(),"resume encounter from disk"):conclude();return
			screen=load("res://scenes/battle.tscn").instantiate()
			add_child(screen)
			check(screen.expedition_runtime.field_ops.data.get("shelter_heard",false) and not Book.met(),"checkpoint remembers hearing the cue without granting early entry")
		finish(screen,outcome!="loss")
		check(Book.met()==(outcome=="win"),"discovery outcome "+outcome)
		check(Book.diary_balance()==(2 if outcome=="win" else 1),"daily diary requires objective and victory: "+outcome)
	check(Book.pages_open()==1 and not Book.available(Book.episodes[1]),"only the first main chapter opens")
	var bag:Dictionary=MetaProgress.yuriko_school.gifts.duplicate()
	check(Expedition.flush_income() and Expedition.load_run() and MetaProgress.yuriko_school.gifts==bag and bag.get("uniform",0)==1,"receipt survives reload without duplicated gifts")
	screen=open_battle("exp_plain",true,5)
	if screen==null:conclude();return
	check(screen.expedition_runtime.field_ops.data.school_finds.keys()==["fragment"],"stage five has only the fragment")
	recover(screen)
	finish(screen,true)
	get_tree().change_scene_to_file("res://scenes/meta.tscn")
	await get_tree().scene_changed
	entry=get_tree().current_scene.find_child("YurikoBaseTab",true,false)
	check(not entry.disabled and entry.text=="百合子","base entry opens after victory")
	entry.pressed.emit()
	await get_tree().scene_changed
	var view=get_tree().current_scene
	check(view.tab==0 and button(view.stage,"继续阅读")!=null,"newly discovered base opens on the first readable chapter")
	button(view.stage,"私信与礼物").pressed.emit()
	var present:=button(view.stage,"赠送 玻璃瓶可乐")
	if not check(present!=null and present.icon!=null,"gift inventory button with icon"):conclude();return
	present.pressed.emit()
	check(view.message.text.contains("碰一下瓶子") and MetaProgress.yuriko_school.affinity==2 and Bonds.give("cola")=="","personal reply, exact gift deduction and affinity")
	var offers:=Book.bonus_options()
	MetaProgress.load_save()
	check(offers==Book.bonus_options() and offers.size()==3 and offers[0]!=offers[1] and offers[1]!=offers[2] and offers[0]!=offers[2],"two earned levels retain the same three distinct first offers after reload")
	button(view.stage,Book.BONUSES[offers[0]]).pressed.emit()
	check(Book.next_bonus_level()==2 and not Book.choose_bonus(1,offers[0]),"first button commits exactly one level")
	var second:=Book.bonus_options()
	var absent:String=""
	for key:String in Book.BONUSES:
		if key not in second:absent=key
	check(not Book.choose_bonus(2,absent),"cannot claim an unoffered attribute")
	button(view.stage,Book.BONUSES[second[1]]).pressed.emit()
	MetaProgress.load_save()
	check(Book.next_bonus_level()==3 and Book.bonus_options().is_empty() and MetaProgress.yuriko_school.affinity_choices==[offers[0],second[1]],"both gift levels can be chosen separately and persist")
	var story:Dictionary=Bonds.stories[0]
	check(button(view.stage,story.title)==null,"gift page omits fragment list")
	button(view.stage,"手记").pressed.emit()
	button(view.stage,"日常活动").pressed.emit()
	button(view.stage,"手记").pressed.emit()
	var locked_titles:Dictionary={}
	for row:Button in view.stage.find_children("*","Button",true,false):
		if row.text.ends_with("解锁 · 带回本篇残章"):
			var help := button(row.get_parent(),"?")
			check(help != null and help.icon != null,"locked fragment has source button")
			if help != null:
				help.pressed.emit()
				check(view.message.text == help.tooltip_text,"question shows fragment source")
				view.message.text = ""
				row.pressed.emit()
				check(view.message.text == help.tooltip_text and view.current.is_empty(),"locked title shows fragment source")
			locked_titles[row.text.get_slice("　",0)]=true
	for ep:Dictionary in Bonds.stories:
		check(locked_titles.has(ep.title)==(not Book.available(ep)),"locked fragment row after switching tabs: "+ep.title)
	button(view.stage,story.title).pressed.emit()
	for step in 32:
		if view.current.is_empty():break
		if Book.choosing(story):button(view.stage,story.choices[1].text).pressed.emit()
		else:
			var words:Label=null
			for l:Label in view.stage.find_children("*","Label",true,false):
				if l.mouse_filter==Control.MOUSE_FILTER_STOP:words=l;break
			if words==null:break
			var event:=InputEventMouseButton.new()
			event.button_index=MOUSE_BUTTON_LEFT
			event.pressed=true
			words.gui_input.emit(event)
	check(view.current.is_empty() and view.tab==0 and MetaProgress.yuriko_school.get("read",{}).get(story.id,-1)==1,"click dialogue and choose second reply, returning to journal")
	check(Book.lines(story,1).has(story.gift_memory.remembered) and Book.balance()==0,"letter remembers gifted cola and preserves independent talent points")
	for index in 3:
		read_chapter(index)
		screen=open_battle("exp_plain")
		if screen==null:conclude();return
		recover(screen)
		finish(screen,true)
		check(Book.pages_open()==index+2,"battle earns next main chapter")
	read_chapter(3)
	check(MetaProgress.yuriko_school.fragments.size()==1 and Book.recruit_ready(),"diary victories advance reunion while preserving the single collected fragment")
	screen=open_battle("exp_plain")
	if screen==null:conclude();return
	recover(screen)
	finish(screen,true)
	check(Expedition.state.get("yuriko_recruited",false),"recover the recruitment letter and win")
	screen=open_battle("exp_plain",false)
	if screen==null:conclude();return
	var field=screen.expedition_runtime.field_ops
	if not check(field.data.has("archive_at"),"pink dossier is available after chapter four and recruitment"):conclude();return
	var marker:Dictionary=field.markers().filter(func(m):return m.key=="school_archive").front()
	check(marker.color==Field.PINK and screen.find_child("YurikoArchive",true,false)!=null,"pink dossier has a map pin and dedicated side-panel action")
	screen.battle.spawn_unit("E1","ally",field.data.archive_at)
	field.tick(.1)
	check(not field.data.get("archive_taken",false),"ordinary squad cannot take the dossier")
	screen.battle._place_building("GAPILE","ally",screen.battle.player_start()+Vector2(145,100),true)
	if not check(Psi.summon(screen.battle),"deploy recruited Yuriko"):conclude();return
	Psi.hero(screen.battle).position=field.data.archive_at
	field.tick(.1)
	check(field.data.get("archive_taken",false),"Yuriko picks up the archive")
	finish(screen,true)
	MetaProgress.load_save()
	check(Book.pages_open()==5 and Book.available(Book.episodes[4]) and not Book.available(Book.episodes[5]),"victory archives exactly one new main chapter")
	for page in range(5,8):
		read_chapter(page-1)
		screen=open_battle("exp_plain",false)
		if screen==null:conclude();return
		field=screen.expedition_runtime.field_ops
		if not check(field.data.has("archive_at") and int(field.data.archive_page)==page+1,"next unread dossier on route"):conclude();return
		screen.battle._place_building("GAPILE","ally",screen.battle.player_start()+Vector2(145,100),true)
		if not check(Psi.summon(screen.battle),"summon at new stage"):conclude();return
		Psi.hero(screen.battle).position=field.data.archive_at
		field.tick(.1)
		finish(screen,true)
		check(Book.pages_open()==page+1,"separate victory opens page "+str(page+1))
	read_chapter(7)
	screen=open_battle("exp_plain",false)
	if screen==null:conclude();return
	check(not screen.expedition_runtime.field_ops.data.has("archive_at"),"no spare dossier after all main chapters")
	finish(screen,true)
	check(not Bonds.give("cola").is_empty() and MetaProgress.yuriko_school.affinity==3,"repeat cola gift receives its own reply and one affinity")
	var last_letter:Dictionary=Bonds.stories[2]
	check(Book.lines(last_letter,0).has(last_letter.invitation.shy),"early invitation stays tentative")
	check(not Bonds.give("uniform").is_empty() and Book.lines(last_letter,1).has(last_letter.invitation.close),"enough affinity changes her invitation")
	var before_read:=Book.affinity_level()
	for ep:Dictionary in Bonds.stories:
		if Book.available(ep):continue
		if not check(not Book.advance(ep),"missing fragment prevents reading "+ep.id):conclude();return
		screen=open_battle("exp_plain",true,5)
		if screen==null:conclude();return
		recover(screen)
		finish(screen,true)
		if not check(Book.available(ep) and Book.affinity_level()==before_read,"victory unlocks only the next story without spending its reading reward "+ep.id):conclude();return
	var carried:=[{"kind":"cache"}]
	Bonds.attach(carried)
	check(carried[0].school_fragment==0,"completed collection still yields gifts without duplicate fragments")
	view.hub(0)
	button(view.stage,"日常活动").pressed.emit()
	button(view.stage,"手记").pressed.emit()
	check(view.tab==0 and button(view.stage,Bonds.stories.back().title)!=null and button(view.stage,"远征残章")==null,"switching back exposes collected fragments directly")
	var settings:={}
	for activity:Dictionary in Book.episodes:
		if activity.kind!="activity":continue
		for step in 32:
			if MetaProgress.yuriko_school.read.has(activity.id):break
			if not Book.advance(activity,0 if Book.choosing(activity) else -1):break
	for talent:Dictionary in Book.talents:
		if not check(Book.learn(talent.id),"learn talent before reading summer stories "+talent.id):conclude();return
	check(MetaProgress.yuriko_school.learned.size()==15 and Book.balance()==0,"full psi tree and no unspent psi points")
	var psi_balance:=Book.balance()
	for ep:Dictionary in Bonds.stories:
		for answer:int in [0,1]:
			var before:=Book.affinity_level()
			button(view.stage,ep.title).pressed.emit()
			if ep.has("affinity_award"):
				var art:Texture2D=view.scenery.texture
				if ep.has("art_cell"):
					var tile:=art as AtlasTexture
					var size:Vector2=view.ACTIVITIES.get_size()/3.0
					var index:=int(ep.art_cell)
					var rect:=Rect2(Vector2(index%3,floori(index/3.0))*size,size).grow(-2)
					check(tile!=null and tile.atlas==view.ACTIVITIES and tile.region==rect,"displayed illustrated location "+ep.id)
					settings[index]=true
				else:
					check(art==(view.HARBOR if ep.background=="harbor" else view.CLASSROOM),"displayed full background "+ep.id)
					settings[ep.background]=true
			for step in 32:
				if view.current.is_empty():break
				var action:Button
				if Book.choosing(ep):
					var speaker:String=ep.get("choice_speaker","百合子")
					var face:TextureRect=view.stage.find_child("SpeakerPortrait",true,false)
					var nameplate:Label=view.stage.find_child("SpeakerName",true,false)
					if speaker=="指挥官":
						var player:=MetaProgress.commander_name()
						check(nameplate.text==("指挥官" if player.is_empty() else player) and face==null and not view.actor_layer.visible,"player choice uses name alone in "+ep.id)
					else:
						check(nameplate.text==speaker and face!=null and face.texture==view.actor_layer.texture and face.texture==view.story_portraits[ep.portrait],"choice shows deciding character in "+ep.id)
					action=button(view.stage,ep.choices[answer].text)
				else:
					action=button(view.stage,"下一句")
					if action==null:action=button(view.stage,"记入手记")
				if action==null:break
				if ep.id=="tide_cover" and answer==0 and action.text.begins_with("记入手记"):
					check(action.text.contains("好感等级 ＋1") and Book.affinity_level()==before,"last page previews unclaimed level")
					var temp_save:=ProjectSettings.globalize_path(MetaProgress.SAVE_PATH+".tmp")
					if not check(DirAccess.make_dir_absolute(temp_save)==OK,"simulate failed completion save"):conclude();return
					action.pressed.emit()
					DirAccess.remove_absolute(temp_save)
					MetaProgress.load_save()
					check(not MetaProgress.yuriko_school.read.has(ep.id) and Book.affinity_level()==before and Book.cursor(ep).step==Book.lines(ep,answer).size()-1,"failed save leaves last page and reward ready to retry")
				action.pressed.emit()
			check(view.tab==0 and view.current.is_empty() and MetaProgress.yuriko_school.read.has(ep.id),"read selectable branch %s/%d"%[ep.id,answer])
			check(Book.affinity_level()==before+(int(ep.get("affinity_award",0)) if answer==0 else 0),"first read grants its level once "+ep.id)
	MetaProgress.load_save()
	check(settings.size()==11 and Book.affinity_level()==before_read+11 and Book.balance()==psi_balance,"all eleven locations grant eleven persisted levels with no psi reward")
	var kept:=MetaProgress.yuriko_school.duplicate(true)
	kept.pages=1
	kept.read={story.id:1}
	kept.erase("fragments")
	check(Book.commit(kept) and not Book.available(Book.episodes[7]) and not Book.available(Bonds.stories[2]),"prepare locked content for GM validation")
	var gm=preload("res://scripts/admin/gm_console.gd").new()
	add_child(gm)
	var unlock:Button=gm.find_child("UnlockYurikoStory",true,false)
	if check(unlock!=null,"GM single-click action exists"):unlock.pressed.emit()
	check(Book.available(Book.episodes[7]) and Book.available(Bonds.stories[2]) and MetaProgress.yuriko_school.read[story.id]==1,"GM opens remaining content and preserves chosen response")
	gm.free()
	var capped:=MetaProgress.yuriko_school.duplicate(true)
	capped.affinity=99
	capped.affinity_choices=[]
	capped.affinity_choices.resize(99)
	capped.affinity_choices.fill("duration")
	capped.gifts.cola=2
	check(Book.commit(capped) and not Bonds.give("cola").is_empty() and Book.affinity_level()==100,"gift reaches level 100")
	check(Book.choose_bonus(100,Book.bonus_options()[0]) and not Bonds.give("cola").is_empty() and Book.affinity_level()==100 and Book.bonus_options().is_empty(),"level 100 offers a final choice and no further upgrades")
	var at_cap:Dictionary=Bonds.stories.back()
	for step in 32:
		if MetaProgress.yuriko_school.read.has(at_cap.id):break
		if not Book.advance(at_cap,0 if Book.choosing(at_cap) else -1):break
	check(MetaProgress.yuriko_school.read.has(at_cap.id) and Book.affinity_level()==100 and Book.bonus_options().is_empty(),"new story remains readable at level cap")
	conclude()
