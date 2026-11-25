extends RefCounted

const People = preload("res://scripts/expedition/contact_catalog.gd").PEOPLE
const Letters = preload("res://scripts/expedition/cycle_letters.gd")
const Gifts = preload("res://scripts/expedition/commander_keepsakes.gd")
const Relics = preload("res://scripts/expedition/relics.gd")
const HEADINGS := {"bio":"人物情报", "promise":"支援约定", "rescue":"救援答话", "arrival":"报到通话"}

static func dialogue(cycle:int) -> Dictionary:
	var pages := {}
	for id:String in People:
		var record:Dictionary = MetaProgress.contact_transcripts.get(id,{})
		var speaker:String = People[id].name
		for kind:String in HEADINGS:
			for text:String in record.get(kind,[]):
				pages[[id,kind,text]] = speaker+" · "+HEADINGS[kind]+"\n"+text
		for chapter:String in MetaProgress.contact_archive.get(id,{}):
			var receipt:Dictionary = MetaProgress.contact_archive[id][chapter]
			var story:Dictionary = People[id].chapters.get(chapter,{})
			pages[[id,"chapter",chapter]] = speaker+" · 《"+str(receipt.get("title",story.get("title",chapter)))+"》\n"+"\n".join(receipt.get("lines",story.get("lines",[])))
		if Gifts.ITEMS.has(id):
			var gift:Dictionary = Gifts.ITEMS[id]
			if record.has("keepsake"):pages[[id,"gift"]] = speaker+" · "+gift.name+"\n"+gift.gift
			for level in range(2, Gifts.rank(id) + 1):
				pages[[id,"gift_reunion",level]] = "%s · 信物第 %d 档\n%s" % [speaker,level,Gifts.story(id,level)]
			if record.has("joint_record"):pages[[id,"joint"]] = speaker+" · 合击战记\n"+gift.after
		var letters:=Letters.letters(id,cycle,record)
		for title:String in letters:pages[[id,"letter",title]] = speaker+" · "+title+"\n"+letters[title]
	return pages

static func capture(previous:Dictionary,next:Dictionary) -> void:
	var pages:=dialogue(int(next.get("cycle",1)))
	var same_run:bool = previous.get("id","") == next.id
	var before:Dictionary = previous if same_run else {}
	var entries:Array = next.get_or_add("gain_journal",[])
	var stage:int = before.get("stage",next.stage)
	if before.get("phase","") in ["event","reward"] and stage>1:
		stage-=1
	var known:Dictionary = before.get("known_dialogue",{})
	for key:Array in pages:
		if not known.has(key) and (before.has("known_dialogue") or (not same_run and key[1]=="letter" and not dialogue_letter_preexisting(key,previous,next))):
			entries.append({"stage":stage,"kind":"dialogue","text":pages[key]})
	next.known_dialogue = keys_of(pages)
	for kind:String in ["relics","buffs","trait_buffs"]:
		for id:String in next.get(kind,{}):
			var old_level:=Relics.level(before,id) if kind=="relics" else int(before.get(kind,{}).get(id,0))
			var new_level:=Relics.level(next,id) if kind=="relics" else int(next[kind][id])
			if new_level>old_level:
				entries.append({"stage":stage,"kind":kind,"id":id,"before":old_level,"after":new_level})

static func dialogue_letter_preexisting(key:Array,previous:Dictionary,run:Dictionary) -> bool:
	var previous_cycle:=int(previous.get("cycle",maxi(1,int(run.get("cycle",1))-1)))
	return Letters.letters(key[0],previous_cycle,MetaProgress.contact_transcripts.get(key[0],{})).has(key[2])

static func keys_of(pages:Dictionary) -> Dictionary:
	var keys:={}
	for key in pages:keys[key]=true
	return keys
