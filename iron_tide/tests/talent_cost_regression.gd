extends "res://tests/ground_control_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	var m=MetaProgress
	m.reset_save()
	for uid in GameData.meta_config.unit_talents:
		for id in m.talent_options(uid):
			var cap:int=m.talent_options(uid)[id].get("ranks",[]).size()
			m.unit_talents={};m.talent_slots={uid:1};m.owned_talent_points=1
			check(m.talent_upgrade_cost(uid,id)==0 and not m.upgrade_talent(uid,id,0),"unallocated talent cannot upgrade "+id)
			m.currency={"cores":1000,"credits":1234,"diamonds":987}
			check(m.set_unit_talent(uid,id) and m.balance("cores")==1000,"rank zero allocation keeps existing cost "+id)
			for rank in cap:
				var cost:int=[40,120,240][rank]
				check(m.talent_upgrade_cost(uid,id)==cost,"exact next rank quote "+id+str(rank))
				m.currency.cores=cost-1
				check(not m.upgrade_talent(uid,id,rank) and m.balance("cores")==cost-1 and m.talent_rank(uid,id,m.unit_talents)==rank,"insufficient cores cannot change wallet or rank "+id+str(rank))
				m.currency.cores=cost
				check(not m.upgrade_talent(uid,id,rank+1) and m.balance("cores")==cost,"stale rank cannot charge "+id+str(rank))
				check(m.upgrade_talent(uid,id,rank) and m.balance("cores")==0,"exact balance purchase charges once "+id+str(rank))
				m.load_save()
				check(m.talent_rank(uid,id,m.unit_talents)==rank+1 and m.balance("cores")==0,"rank and debit persist "+id+str(rank))
			check(m.talent_upgrade_cost(uid,id)==0 and not m.upgrade_talent(uid,id,cap),"maximum rank cannot charge "+id)
			check(m.balance("credits")==1234 and m.balance("diamonds")==987,"other currency unchanged "+id)
	# Existing purchased ranks incur no retroactive debit; the next transaction uses the new price.
	m.unit_talents={"SHK":{"tesla_reserve":2}};m.talent_slots={"SHK":1};m.owned_talent_points=1
	m.currency.cores=500
	m.save();m.load_save();m.load_save()
	check(m.talent_rank("SHK","tesla_reserve",m.unit_talents)==2 and m.balance("cores")==500 and m.talent_upgrade_cost("SHK","tesla_reserve")==240,"existing rank retained without catch-up charge")
	for old_rank in [3,4]:
		m.unit_talents.DESO={"deso_expansion":old_rank};m.owned_talent_points=2
		m.save();m.load_save();m.load_save()
		check(m.unit_talents.DESO.deso_expansion==3 and m.balance("cores")==500,"old radiation rank merges to max without debit "+str(old_rank))
		check(m.talent_options("DESO").deso_expansion.intervals[3]==1.5 and m.talent_options("DESO").deso_expansion.ranks[2].value==4,"merged radiation tier keeps former final benefit")
	var previous:=FileAccess.get_file_as_bytes(m.SAVE_PATH)
	DirAccess.make_dir_absolute(m.SAVE_PATH+".tmp")
	check(not m.upgrade_talent("SHK","tesla_reserve",2) and m.balance("cores")==500 and m.talent_rank("SHK","tesla_reserve",m.unit_talents)==2,"failed save rolls back price and rank")
	check(FileAccess.get_file_as_bytes(m.SAVE_PATH)==previous,"failed save preserves profile bytes")
	DirAccess.remove_absolute(m.SAVE_PATH+".tmp")
	var ui=load("res://scenes/meta.tscn").instantiate()
	add_child(ui);ui._unit_sel="SHK"
	for rank in 3:
		var price:int=[40,120,240][rank]
		m.unit_talents.SHK.tesla_reserve=rank;m.currency.cores=price-1
		ui._rebuild_unit_detail()
		var button=ui.unit_detail.find_child("UpgradeTalent_tesla_reserve",true,false)
		check(button!=null and button.disabled and button.text.contains(str(price)+" 战略核心"),"UI quote and insufficient state rank "+str(rank))
		m.currency.cores=price;ui._rebuild_unit_detail()
		button=ui.unit_detail.find_child("UpgradeTalent_tesla_reserve",true,false)
		check(not button.disabled,"UI exact funds enables rank "+str(rank))
		button.pressed.emit()
		check(m.balance("cores")==0 and m.talent_rank("SHK","tesla_reserve",m.unit_talents)==rank+1,"real UI purchase matches price rank "+str(rank))
	ui._set_page("units");ui._unit_sel="IVAN"
	m.unit_talents.erase("IVAN");m.talent_slots.IVAN=1;m.owned_talent_points=m.redeemed_points_in_use()
	var point_price:int=m.talent_shop_price()
	var point_currency:String=m.talent_shop_currency()
	m.currency[point_currency]=point_price-1;ui._rebuild_unit_detail()
	var unlock=ui.unit_detail.find_child("Talent_native_fuse",true,false)
	check(unlock!=null and unlock.disabled and unlock.text.contains(str(point_price)+" 战略核心"),"direct unlock shows price and insufficient state")
	m.currency[point_currency]=point_price;m.save();ui._rebuild_unit_detail()
	unlock=ui.unit_detail.find_child("Talent_native_fuse",true,false)
	check(not unlock.disabled,"direct unlock enabled with exact funds")
	var before_bytes:=FileAccess.get_file_as_bytes(m.SAVE_PATH)
	DirAccess.make_dir_absolute(m.SAVE_PATH+".tmp")
	unlock.pressed.emit()
	check(m.balance(point_currency)==point_price and not m.unit_talents.has("IVAN") and FileAccess.get_file_as_bytes(m.SAVE_PATH)==before_bytes,"failed direct unlock restores wallet talent and disk")
	DirAccess.remove_absolute(m.SAVE_PATH+".tmp")
	unlock.pressed.emit()
	check(m.balance(point_currency)==0 and m.unassigned_talent_points()==0 and m.unit_talents.IVAN.native_fuse==0,"direct unlock charges once and assigns rank zero")
	check(ui._page=="units" and ui._unit_sel=="IVAN","direct unlock stays on same unit")
	check(ui.unit_detail.find_child("Talent_native_fuse",true,false)==null and ui.unit_detail.find_child("BuyTalentPoint",true,false)==null,"full talent hides unlock and point purchase")
	unlock.pressed.emit()
	check(m.balance(point_currency)==0 and m.unassigned_talent_points()==0,"stale repeated click cannot buy another point")
	m.load_save()
	check(m.balance(point_currency)==0 and m.unit_talents.IVAN.native_fuse==0,"direct unlock persists after reload")
	ui._set_page("shop")
	check(ui.shop_body.find_child("RedeemTalentPoint",true,false)==null,"shop no longer sells points")
	ui.free()
	check(m.Academy.hero_talent_cost("survival",4)==600 and m.talent_shop_price()==40,"hero escalating cost and unchanged point shop")
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed==0 else 1)
