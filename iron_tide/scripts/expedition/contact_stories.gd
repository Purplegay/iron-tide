extends RefCounted

const PEOPLE=preload("res://scripts/expedition/contact_catalog.gd").PEOPLE
const CHAPTERS_PER_RUN:=4

static func next_chapter(id:String,archive:Dictionary) -> String:
	var read:Dictionary=archive.get(id,{})
	for key:String in PEOPLE.get(id,{}).get("chapters",{}):
		if not read.has(key):return key
	return ""

static func select_contact(stage:int,seed_value:int,history:Array,archive:Dictionary) -> String:
	var ids:=PEOPLE.keys()
	var offset:=posmod(stage+seed_value,ids.size())
	var pending:={}
	for prior:Dictionary in history:
		if int(prior.stage)>=stage:pending[prior.id]=true
	var best:String=ids[offset]
	var best_reads:=-1
	for i in ids.size():
		var id:String=ids[(offset+i)%ids.size()]
		if next_chapter(id,archive).is_empty():continue
		var reads:int=archive.get(id,{}).size()
		if best_reads>=0:
			if pending.has(id) and not pending.has(best):continue
			if pending.has(id)==pending.has(best) and reads>=best_reads:continue
		best=id
		best_reads=reads
	return best

# The receipt identifies the allied commander's actual appearance, even if the
# player reopens an older battle checkpoint or leaves before the battle ends.
static func available_chapter(id:String,run_id:String,stage:int,archive:Dictionary) -> String:
	if run_id.is_empty() or stage<1:return ""
	var count:=0
	for actor_id:String in archive:
		for receipt:Dictionary in archive[actor_id].values():
			if receipt.run!=run_id:continue
			if actor_id==id and int(receipt.stage)==stage:return ""
			count+=1
	if count>=CHAPTERS_PER_RUN:return ""
	return next_chapter(id,archive)

static func rescue_line(person:Dictionary) -> String:
	return PEOPLE.get(person.id,{}).get("rescue",person.get("bio",""))

static func mission_text(person:Dictionary) -> Dictionary:
	var lines:={"bio":str(person.get("bio",""))}
	if person.get("promise","")!="":
		lines.promise="约定第 %d 关：%s"%[person.stage,person.promise]
	return lines

static func remember(records:Dictionary,id:String,lines:Dictionary) -> bool:
	if not PEOPLE.has(id):return false
	var entry:Dictionary=records.get_or_add(id,{})
	var changed:=false
	for kind:String in lines:
		var line:String=lines[kind]
		if line.is_empty():continue
		var variants:Array=entry.get_or_add(kind,[])
		if line not in variants:
			variants.append(line)
			changed=true
	return changed

static func recover_contacts(run:Dictionary,records:Dictionary) -> bool:
	var rescued:Array=run.get("field_contacts",[]).duplicate()
	for report:Dictionary in run.get("battle_reports",[]):
		rescued.append_array(report.get("field_contacts",[]))
	var changed:=false
	for person:Dictionary in rescued:
		var id:String=person.id
		if not PEOPLE.has(id):continue
		if remember(records,id,mission_text(person)):changed=true
		if not records[id].get("rescued",false):
			records[id].rescued=true
			changed=true
	return changed
