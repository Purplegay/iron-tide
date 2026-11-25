extends Node

const Growth=preload("res://scripts/expedition/growth.gd")
var failed:=0

func check(ok:bool,description:String) -> void:
	if not ok:
		failed+=1
		push_error(description+" · "+Expedition.error)

func _ready() -> void:
	if not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	check(Expedition.start("美国","",291),"建立远征")
	var next:=Expedition.state.duplicate(true)
	Expedition.ready(next)
	next.relics[Growth.RELIC]=true
	next.licenses.erase("GHOST")
	next.unit_growth["GHOST"]={"atk":0,"def":0}
	check(Expedition.commit(next),"保存营地")
	var balance:=int(Expedition.state.supplies)
	check(not Expedition.service("training","GHOST","a",0) and Expedition.error=="尚未持有该兵种" and Growth.free_available(Expedition.state),"未持有时保留免费次数")
	next=Expedition.state.duplicate(true)
	Expedition.grant(next,{"kind":"special_unit","id":"GHOST","tier":3,"count":1})
	check(Expedition.commit(next) and "GHOST" in Expedition.state.licenses,"获得特装 III 海豹部队时取得本轮许可")
	check(Expedition.service("training","GHOST","a",0),"使用免费强化")
	check(Expedition.state.unit_growth.GHOST=={"atk":1,"def":1} and int(Expedition.state.supplies)==balance and not Growth.free_available(Expedition.state),"攻防各升一级且只消耗免费次数")
	check(not Expedition.service("training","GHOST","a",0) and int(Expedition.state.supplies)==balance,"重复提交免费强化不会扣费")
	check(Expedition.service("training","GHOST","a",Growth.PRICE),"使用补给强化")
	check(Expedition.load_run() and Expedition.state.unit_growth.GHOST=={"atk":2,"def":2} and int(Expedition.state.supplies)==balance-Growth.PRICE,"重新载入后保留等级及补给余额")
	next=Expedition.state.duplicate(true)
	next.licenses.erase("GHOST")
	check(Expedition.commit(next) and Expedition.load_run() and "GHOST" in Expedition.state.licenses,"旧档按仍持有的特装小队补回许可")
	check(Expedition.service("refill","GHOST"),"特装援助兵种可以直接补员")
	var rules=preload("res://scripts/expedition/rules.gd")
	check(Expedition.launch(0) and rules.active() and rules.licensed_production("GHOST","ally") and rules.block_reason("GHOST","ally").is_empty(),"战场生产入口认可海豹部队许可")
	print("SPECIAL_TRAINING failed=",failed)
	get_tree().quit(1 if failed else 0)
