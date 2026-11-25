extends "res://tests/ground_control_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	var m=MetaProgress
	var academy=m.Academy
	m.reset_save()
	var page=load("res://scripts/ui/hero_progression.gd").new()
	add_child(page)
	for id in academy.LEGACY_HEROES:
		m.academy.hero_builds={id:academy.hero_requirement(id)}
		page.selected=id
		for action in ["escort","survival"]:
			var key:String="hero_escort_ranks" if action=="escort" else "hero_survival_ranks"
			var cap:int=3 if action=="escort" else 5
			m.academy[key]={id:0}
			for rank in cap:
				var price:int=[40,120,240,400,600][rank]
				check(academy.hero_talent_cost(action,rank)==price,"quote "+id+action+str(rank))
				m.currency={"cores":price-1,"credits":1234,"diamonds":987}
				page.refresh()
				var button=page.escort if action=="escort" else page.survival
				check(button.disabled and button.text.contains(str(price)+" 战略核心"),"UI insufficient quote "+id+action+str(rank))
				check(not academy.purchase(m,action,id) and m.balance("cores")==price-1 and m.academy[key][id]==rank,"reject insufficient balance without mutation")
				m.currency.cores=price;page.refresh()
				check(not button.disabled,"exact balance enables purchase")
				button.pressed.emit()
				check(m.balance("cores")==0 and m.academy[key][id]==rank+1,"actual UI charges next-rank price")
				m.load_save();m.load_save()
				check(m.balance("cores")==0 and m.academy[key][id]==rank+1,"persisted rank no retroactive charge")
				check(m.balance("credits")==1234 and m.balance("diamonds")==987,"other currencies unchanged")
			m.currency.cores=10000;page.refresh()
			check(academy.hero_talent_cost(action,cap)==0 and not academy.purchase(m,action,id) and m.balance("cores")==10000,"max cannot charge "+id+action)
			m.academy.hero_builds[id]=0
			m.academy[key][id]=0;page.refresh()
			check(not academy.purchase(m,action,id) and (page.escort if action=="escort" else page.survival).disabled,"locked hero cannot upgrade")
			m.academy.hero_builds[id]=academy.hero_requirement(id)
	# Atomic persistence failure preserves previously purchased levels and wallet.
	m.academy.hero_builds={"E1":50};m.academy.hero_survival_ranks={"E1":4};m.currency.cores=900
	m.save();m.load_save();m.load_save()
	check(m.balance("cores")==900 and m.academy.hero_survival_ranks.E1==4,"existing high rank preserved without catch-up debit")
	var previous:=FileAccess.get_file_as_bytes(m.SAVE_PATH)
	DirAccess.make_dir_absolute(m.SAVE_PATH+".tmp")
	check(not academy.purchase(m,"survival","E1") and m.balance("cores")==900 and m.academy.hero_survival_ranks.E1==4,"failed save rolls back transaction")
	check(previous==FileAccess.get_file_as_bytes(m.SAVE_PATH),"failed save leaves profile bytes intact")
	DirAccess.remove_absolute(m.SAVE_PATH+".tmp")
	check(academy.purchase(m,"survival","E1") and m.balance("cores")==300,"retry charges once")
	check(academy.hero_talent_cost("escort",-1)==0 and academy.hero_talent_cost("invalid",0)==0,"invalid quote rejected")
	page.free()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed==0 else 1)
