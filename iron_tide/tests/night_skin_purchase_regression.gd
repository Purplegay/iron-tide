extends "res://tests/base_recovery_regression.gd"
const Looks=preload("res://scripts/units/night_hunter_skin.gd")
const Catalog=preload("res://scripts/rules/cosmetic_catalog.gd")
const Picker=preload("res://scripts/ui/unit_skin_picker.gd")
const Shop=preload("res://scripts/screens/paint_screen.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	for id in Looks.SKINS:
		await purchase(id,false)
		await purchase(id,true)
		await rollback(id,false)
		await rollback(id,true)
		await ownership_and_battle(id)
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0},"  "))
	print("NIGHT_SKIN_PURCHASE_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func select(picker:OptionButton,value:String) -> int:
	for i in picker.item_count:
		if picker.get_item_metadata(i)==value:
			picker.select(i);picker.item_selected.emit(i);return i
	check(false,"missing real picker option "+value);return -1

func workshop(id:String):
	var shop=Shop.new();shop.initial_unit=id;shop.size=Vector2(1280,720);add_child(shop)
	shop.set_process(false);shop.preview.set_process(false)
	return shop

func purchase(id:String,ticket:bool) -> void:
	var skin:String=Looks.SKINS[id];var label:=id+(" ticket" if ticket else " diamonds")
	MetaProgress.reset_save();MetaProgress.currency.diamonds=5999
	check(Catalog.price("skin")==6000 and not MetaProgress.cosmetic_owned(skin) and not Catalog.effect_text(id,"skin",skin).contains("免费体验"),label+" is priced and no longer implicitly owned")
	check(not MetaProgress.set_cosmetic(id,"skin",skin) and not MetaProgress.buy_cosmetic(id,"skin",skin) and MetaProgress.balance("diamonds")==5999,label+" insufficient funds cannot buy or equip")
	check(not MetaProgress.buy_cosmetic("MTNK","skin",skin) and not MetaProgress.buy_cosmetic(id,"paint",skin),label+" wrong chassis and slot rejected")
	var shop=workshop(id);var picker:OptionButton=shop.slots.find_child("skin",true,false)
	var index:=select(picker,skin);var button:Button=shop.slots.find_child("Buy_skin",true,false)
	check(index>=0 and picker.get_item_text(index).contains("6000") and button.visible and button.disabled,label+" actual workshop shows price and disabled purchase")
	check(shop.preview.actor.night_skin!=null and not MetaProgress.cosmetic_owned(skin) and MetaProgress.cosmetic_style(id).get("skin","stock")=="stock",label+" locked preview uses real skin without granting ownership or equipping")
	MetaProgress.currency.diamonds=6100;MetaProgress.academy.skin_ticket=1 if ticket else 0
	shop._select_unit(id);picker=shop.slots.find_child("skin",true,false);select(picker,skin);button=shop.slots.find_child("Buy_skin",true,false)
	check(button.visible and not button.disabled and button.text==("使用皮肤券并装配" if ticket else "购买并装配"),label+" real purchase button selects correct payment method")
	button.pressed.emit()
	var expected:=6100 if ticket else 100
	check(MetaProgress.balance("diamonds")==expected and MetaProgress.academy.skin_ticket==0 and MetaProgress.cosmetic_owned(skin) and MetaProgress.cosmetic_style(id).get("skin")==skin,label+" actual button debits once and purchases plus equips")
	check(shop.status.text.contains("已购买并装配") and shop.preview.actor.night_skin!=null,label+" workshop refresh consumes owned selection")
	check(not MetaProgress.buy_cosmetic(id,"skin",skin) and MetaProgress.balance("diamonds")==expected,label+" duplicate purchase rejected without debit")
	MetaProgress.load_save()
	check(MetaProgress.cosmetic_owned(skin) and MetaProgress.owned_cosmetics.get(skin,false) and MetaProgress.cosmetic_style(id).get("skin")==skin and MetaProgress.balance("diamonds")==expected,label+" actual save reload retains explicit ownership, outfit and wallet")
	var refit:=Picker.new();add_child(refit);refit.setup(id,shop.preview)
	var equipped_index:=select(refit.picker,skin)
	check(not refit.picker.is_item_disabled(equipped_index) and refit.status.text.contains("已装备") and MetaProgress.balance("diamonds")==expected,label+" refit can equip owned skin without another payment")
	check(MetaProgress.set_cosmetic(id,"skin","stock") and MetaProgress.set_cosmetic(id,"skin",skin) and MetaProgress.balance("diamonds")==expected,label+" switching stock and back is free")
	refit.free();shop.free();await get_tree().process_frame

func rollback(id:String,ticket:bool) -> void:
	var skin:String=Looks.SKINS[id];var label:=id+(" ticket rollback" if ticket else " diamonds rollback")
	MetaProgress.reset_save();MetaProgress.currency.diamonds=7000;MetaProgress.academy.skin_ticket=1 if ticket else 0
	MetaProgress.owned_cosmetics.winter=true;MetaProgress.unit_cosmetics[id]={"skin":"winter"};MetaProgress.save()
	var before:=FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH)
	DirAccess.make_dir_absolute(MetaProgress.SAVE_PATH+".tmp")
	check(not MetaProgress.buy_cosmetic(id,"skin",skin),label+" real save failure rejects purchase")
	check(MetaProgress.balance("diamonds")==7000 and MetaProgress.academy.skin_ticket==(1 if ticket else 0) and not MetaProgress.cosmetic_owned(skin) and MetaProgress.cosmetic_style(id).get("skin")=="winter",label+" restores wallet, voucher, ownership and previous outfit")
	check(FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH)==before,label+" previous profile bytes remain intact")
	DirAccess.remove_absolute(MetaProgress.SAVE_PATH+".tmp")
	check(MetaProgress.buy_cosmetic(id,"skin",skin) and MetaProgress.balance("diamonds")== (7000 if ticket else 1000),label+" retry charges once after storage recovers")
	MetaProgress.load_save();check(MetaProgress.cosmetic_owned(skin) and MetaProgress.cosmetic_style(id).get("skin")==skin,label+" retry persists successful purchase")
	await get_tree().process_frame

func ownership_and_battle(id:String) -> void:
	var skin:String=Looks.SKINS[id]
	MetaProgress.reset_save();MetaProgress.unit_cosmetics[id]={"skin":skin};MetaProgress.save();MetaProgress.load_save()
	check(not MetaProgress.cosmetic_owned(skin) and MetaProgress.cosmetic_style(id).get("skin","stock")=="stock",id+" outfit alone is not proof of purchase under existing load sanitization")
	var shop=workshop(id);var refit:=Picker.new();add_child(refit);refit.setup(id,shop.preview)
	var index:=select(refit.picker,skin)
	check(refit.picker.is_item_disabled(index) and refit.picker.get_item_text(index).contains("6000") and not MetaProgress.cosmetic_owned(skin),id+" locked refit lists acquisition requirement and rejects forced selection")
	refit.free();shop.free()
	MetaProgress.currency.diamonds=0;MetaProgress.academy.skin_ticket=1
	check(MetaProgress.buy_cosmetic(id,"skin",skin) and MetaProgress.balance("diamonds")==0 and MetaProgress.academy.skin_ticket==0,id+" voucher alone works with no diamonds")
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		start(mode)
		var actor=battle.spawn_unit(id,"ally",Vector2(1200,1200));var enemy=battle.spawn_unit(id,"enemy",Vector2(1400,1200))
		check(actor.night_skin!=null and enemy.night_skin==null,id+" purchased skin reaches real actor only for owner in "+mode)
		check(actor.max_hp==enemy.max_hp and actor.radius==enemy.radius,id+" price change does not change life or collision in "+mode)
		var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
		var file=FileAccess.open(output_dir.path_join(id+"-"+mode+".bin"),FileAccess.WRITE);file.store_var(snapshot,false);file.close()
		file=FileAccess.open(output_dir.path_join(id+"-"+mode+".bin"),FileAccess.READ);snapshot=file.get_var(false);file.close();codec.restore(battle,snapshot)
		var restored=null
		for unit in battle.units:
			if unit.unit_id==id and unit.side=="ally":restored=unit
		check(codec.error.is_empty() and restored!=null and restored.night_skin!=null,id+" actual binary battle restore retains owned renderer in "+mode)
		await finish()
