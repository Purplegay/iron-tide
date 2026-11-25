extends "res://tests/base_recovery_regression.gd"
const Market=preload("res://scripts/expedition/market.gd")
const Growth=preload("res://scripts/expedition/growth.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	var run:Dictionary={"seed":1234,"stage":1,"licenses":["E1","GGI"],"special_squads":[],"shop":[],"buffs":{},"trait_buffs":{},"unit_growth":{"E1":{"atk":0,"def":0},"GGI":{"atk":0,"def":0}},"relics":{},"frozen":{"expedition_growth_disabled":{}}}
	var prices:={}
	for roll in 120:
		var item:={"kind":"training","id":"E1"}
		Market.roll_shop_prices([item],Market.rng(run,"discount_"+str(roll)))
		prices[item.price]=true
		check(item.discounted and item.price==floori(25*(100-item.sale_percent)/100.0),"discount price exact "+str(roll))
		check(item.original_price==25,"original price exact "+str(roll))
	check(prices.has_all([7,10,12]) and prices.size()==3,"all three discounted growth prices occur")
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	print("GROWTH_DISCOUNT checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
