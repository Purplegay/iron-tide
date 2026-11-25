extends RefCounted
const Pool=preload("res://scripts/rules/hero_contract_pool.gd")
const Loadouts=preload("res://scripts/rules/hero_loadouts.gd")
const Icon=preload("res://scripts/ui/progression_icon.gd")

static func run(t) -> void:
	var ui=load("res://scenes/meta.tscn").instantiate()
	ui.initial_page="pool"
	ui.training_group="英雄"
	t.add_child(ui)
	var hashes:Array=[]
	var ordinary:Dictionary={}
	for row in Pool.entries():
		ordinary[row.hero_id]=MetaProgress.unit_loadout(row.hero_id).duplicate(true)
		var ids:Array=[row.id]
		ids.append_array(row.cards)
		for id in ids:
			var texture:=Icon.texture(id)
			t.check(texture!=null and texture.get_size()==Vector2(64,64),"gold hero icon exists "+id)
			if texture!=null:
				var digest:=texture.get_image().get_data().hex_encode().sha256_text()
				t.check(not hashes.has(digest),"hero and skill emblems are distinct "+id)
				hashes.append(digest)
		for id in row.cards:
			var button:Button=ui.pool_body.find_child("QuickEquip_"+id,true,false)
			t.check(button!=null and button.disabled,"unearned hero card cannot quick equip "+id)
	preload("res://scripts/admin/gm_hero_contracts.gd").complete(MetaProgress)
	var funds:Dictionary=MetaProgress.currency.duplicate(true)
	var ranks:Dictionary=MetaProgress.academy.get("levels",{}).duplicate(true)
	for row in Pool.entries():
		for id in row.cards:
			var button:Button=ui.pool_body.find_child("QuickEquip_"+id,true,false)
			t.check(button!=null and not button.disabled,"earned hero card exposes quick equip "+id)
			button.pressed.emit()
			var equipped:=Loadouts.effective(MetaProgress,row.hero_id)
			var kind:String=GameData.get_skill(id).type
			t.check(id in equipped.active if kind=="active" else id==equipped.passive,"real button equips matching hero slot "+id)
			button=ui.pool_body.find_child("QuickEquip_"+id,true,false)
			t.check(button.disabled and button.text.begins_with("已装配到"),"quick equip state refreshes immediately "+id)
	var saved:Dictionary=MetaProgress.academy.hero_loadouts.duplicate(true)
	MetaProgress.load_save()
	t.check(MetaProgress.academy.hero_loadouts==JSON.parse_string(JSON.stringify(saved)),"quick equipped hero slots survive save reload")
	t.check(MetaProgress.currency==funds and MetaProgress.academy.get("levels",{})==ranks,"quick equip preserves currency and ranks")
	ui._set_page("heroes")
	for row in Pool.entries():
		t.check(MetaProgress.unit_loadout(row.hero_id)==ordinary[row.hero_id],"quick equip preserves ordinary unit loadout "+row.hero_id)
		ui.heroes.selected=row.hero_id
		ui.heroes.refresh()
		var panel=ui.heroes.contract_panel if row.hero_id=="E2" else ui.heroes.expansion_contract
		var icon:TextureRect=panel.find_child("ContractIcon",true,false)
		t.check(icon!=null and icon.texture==Icon.texture(row.id) and icon.material!=null,"hero progression uses shared contract icon "+row.id)
		for id in row.cards:
			var badge:TextureRect=panel.find_child("RewardIcon_"+id,true,false)
			t.check(badge!=null and badge.texture==Icon.texture(id) and badge.material!=null,"hero progression uses shared reward icon "+id)
			var button:Button=panel.find_child("QuickEquip_"+id,true,false)
			t.check(button!=null and button.disabled and button.text.begins_with("已装配到"),"hero progression shares equip status "+id)
	ui.free()
	await t.get_tree().process_frame
