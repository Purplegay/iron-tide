extends RefCounted
## 胜利记录先存远征档，货币与领取凭据再一起存局外档；中断后可安全重试。
const Campaign=preload("res://scripts/expedition/campaign.gd")

static func quote(stage:int) -> Dictionary:
	var chapter:=Campaign.chapter(stage)
	return {"credits":800+400*chapter,"cores":20+10*chapter}

static func receipt(run:Dictionary,row:Dictionary) -> String:
	return "expedition:%s:%d"%[run.id,int(row.stage)]

static func has_pending(run:Dictionary,meta) -> bool:
	for row:Dictionary in run.get("history",[]):
		if row.has("income") and not meta.settled_matches.has(receipt(run,row)):return true
	return false

static func deliver(run:Dictionary,meta) -> bool:
	var previous_currency:Dictionary=meta.currency.duplicate(true)
	var previous_receipts:Dictionary=meta.settled_matches.duplicate(true)
	var changed:=false
	for row:Dictionary in run.get("history",[]):
		if not row.has("income"):continue
		var key:=receipt(run,row)
		if meta.settled_matches.has(key):continue
		var reward:Dictionary=row.income.duplicate()
		reward.erase("strategy_points")
		meta.currency.credits=meta.balance("credits")+int(reward.credits)
		meta.currency.cores=meta.balance("cores")+int(reward.cores)
		meta.settled_matches[key]=reward.duplicate()
		changed=true
	if not changed:return true
	if not meta.save():
		meta.currency=previous_currency
		meta.settled_matches=previous_receipts
		return false
	Events.meta_changed.emit()
	return true

static func summary(run:Dictionary,meta) -> String:
	var paid:={"credits":0,"cores":0}
	var pending:={"credits":0,"cores":0}
	for row:Dictionary in run.get("history",[]):
		if not row.has("income"):continue
		var target:Dictionary=paid if meta.settled_matches.has(receipt(run,row)) else pending
		for key:String in target:target[key]+= int(row.income.get(key,0))
	var text:="远征额外已到账：军需券 %d · 战略核心 %d（失败仍保留）"%[paid.credits,paid.cores]
	if pending.credits>0 or pending.cores>0:text+="\n待补发：军需券 %d · 战略核心 %d"%[pending.credits,pending.cores]
	return text

static func history_text(run:Dictionary,row:Dictionary,meta) -> String:
	if not row.has("income"):return ""
	return " · 军需券 +%d · 战略核心 +%d（%s）"%[row.income.credits,row.income.cores,"已到账" if meta.settled_matches.has(receipt(run,row)) else "待补发"]
