extends RefCounted
## Completed readings, choices and study belong to the local commander profile.
static var episodes:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/yuriko_school.json"))
static var affinity_stories:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/yuriko_affinity.json"))
static var talents:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/yuriko.json")).tree
const AFFINITY_CAP := 100
const BONUS_CAP := 20
const BONUSES := {"health":"生命 +1%","attack":"攻击 +1%","duration":"驻场 +2 秒","speed":"移速 +0.5%","cooldown":"技能冷却 −0.25%"}

static func affinity_level() -> int:
	return clampi(int(MetaProgress.yuriko_school.get("affinity",0)),0,AFFINITY_CAP)

static func add_affinity(next:Dictionary,amount:int) -> void:
	if amount<=0:return
	if not next.has("affinity_seed"):
		next.affinity_seed=0 if int(next.get("affinity",0))>0 else randi()
	next.affinity=mini(AFFINITY_CAP,int(next.get("affinity",0))+amount)

## Keep the first 20 ranks per attribute on legacy profiles. Overflow becomes unspent choices.
static func capped_bonus_choices() -> Array:
	var choices := []
	var counts := {}
	for key in MetaProgress.yuriko_school.get("affinity_choices", []):
		var count: int = counts.get(key, 0)
		if not BONUSES.has(key) or count >= BONUS_CAP:continue
		counts[key] = count + 1
		choices.append(key)
	return choices

static func next_bonus_level() -> int:
	return capped_bonus_choices().size()+1

static func bonus_options() -> Array:
	var level := next_bonus_level()
	if level>affinity_level():return []
	var roll := RandomNumberGenerator.new()
	roll.seed=hash([int(MetaProgress.yuriko_school.get("affinity_seed",0)),level])
	var counts := bonus_counts()
	var pool := BONUSES.keys().filter(func(key): return counts.get(key, 0) < BONUS_CAP)
	var options:=[]
	for i in mini(3, pool.size()):options.append(pool.pop_at(roll.randi_range(0,pool.size()-1)))
	return options

static func choose_bonus(level:int,key:String) -> bool:
	if level!=next_bonus_level() or key not in bonus_options():return false
	var next:=MetaProgress.yuriko_school.duplicate(true)
	var choices := capped_bonus_choices()
	choices.append(key)
	next.affinity_choices = choices
	return commit(next)

static func bonus_counts() -> Dictionary:
	var counts:={}
	for key in capped_bonus_choices():
		counts[key]=int(counts.get(key,0))+1
	return counts

static func commit(next:Dictionary) -> bool:
	var previous:=MetaProgress.yuriko_school
	MetaProgress.yuriko_school=next
	if MetaProgress.save():return true
	MetaProgress.yuriko_school=previous
	return false

static func chapter_count() -> int:
	var read:Dictionary=MetaProgress.yuriko_school.get("read",{})
	var count:=0
	for ep in episodes:
		if ep.kind=="chapter" and read.has(ep.id):count+=1
	return count

static func chapter_total() -> int:
	var count:=0
	for ep in episodes:
		if ep.kind=="chapter":count+=1
	return count

static func pages_open() -> int:
	return maxi(chapter_count(),int(MetaProgress.yuriko_school.get("pages",0)))

static func met() -> bool:
	return pages_open()>0 or MetaProgress.yuriko_school.get("gm_open",false)

const RETURN_HINT := "找到日常日记或破碎残章，百合子就会加入本轮远征，当场可以召唤。"

static func recruited_before() -> bool:
	return MetaProgress.yuriko_school.get("recruited_before",false) or pages_open() >= 5

static func recruit_ready() -> bool:
	return MetaProgress.yuriko_school.get("read",{}).has("again") or contact_ready()

static func diary_balance() -> int:
	return int(MetaProgress.yuriko_school.get("daily_diaries",0))

static func unlock_diary(ep:Dictionary) -> bool:
	if not episodes.has(ep) or not ep.has("diary_cost") or not met() or available(ep):return false
	if diary_balance()<int(ep.diary_cost):return false
	var next:=MetaProgress.yuriko_school.duplicate(true)
	next.daily_diaries=diary_balance()-int(ep.diary_cost)
	next.get_or_add("diary_unlocked",{})[ep.id]=true
	return commit(next)

static func available(ep:Dictionary) -> bool:
	var state:=MetaProgress.yuriko_school
	if state.get("gm_open",false):return true
	if not met():return false
	if ep.kind=="affinity":return affinity_level()>=int(ep.level)
	if ep.has("diary_cost"):return state.get("diary_unlocked",{}).has(ep.id)
	if ep.kind=="bond":return state.get("fragments",{}).has(str(int(ep.fragment)))
	if ep.kind=="chapter" and pages_open()<=int(ep.unlock):return false
	return chapter_count()>=int(ep.unlock)

static func balance() -> int:
	var state:=MetaProgress.yuriko_school
	var read:Dictionary=state.get("read",{})
	var earned:=0
	for ep in episodes:
		if read.has(ep.id):earned+=int(ep.award)
	for talent in talents:
		if talent.id in state.get("learned",[]):earned-=int(talent.cost)
	return earned

const WEDDING_CG_PRICE:=100000

static func owns_wedding_cg() -> bool:
	return MetaProgress.yuriko_school.get("cg_album",{}).get("same_stop",false)

static func buy_wedding_cg() -> String:
	if owns_wedding_cg():return ""
	if not met():return "请先与百合子相遇。"
	if not journal_head_unlocked():return WEDDING_HEAD_REQUIREMENT
	var funds:=MetaProgress.balance("diamonds")
	if funds<WEDDING_CG_PRICE:return "钻石不足。"
	var next:=MetaProgress.yuriko_school.duplicate(true)
	next.get_or_add("cg_album",{})["same_stop"]=true
	MetaProgress.currency.diamonds=funds-WEDDING_CG_PRICE
	if not commit(next):
		MetaProgress.currency.diamonds=funds
		return "收藏未能保存，请重试。"
	Events.meta_changed.emit()
	return ""

const WEDDING_OUTFIT:=3
const WEDDING_HEAD_REQUIREMENT:="请先解锁手记头型：好感达到 20 级，并读完第五章《靠窗第三排》。"
const OUTFIT_CHAPTERS:=["","desk","letter"]

const JOURNAL_HEAD_AFFINITY := 20
const JOURNAL_HEAD_CHAPTER := "desk"

static func journal_head_unlocked() -> bool:
	return affinity_level() >= JOURNAL_HEAD_AFFINITY and MetaProgress.yuriko_school.get("read",{}).has(JOURNAL_HEAD_CHAPTER)

static func journal_head_equipped() -> bool:
	return MetaProgress.yuriko_school.get("journal_head",false) and journal_head_unlocked()

static func wear_journal_head(equip:bool) -> bool:
	if equip and not journal_head_unlocked():return false
	var next:=MetaProgress.yuriko_school.duplicate(true)
	next.journal_head=equip
	return commit(next)

static func outfit_unlocked(index:int) -> bool:
	if index==WEDDING_OUTFIT:return owns_wedding_cg() and journal_head_unlocked()
	if index<0 or index>=OUTFIT_CHAPTERS.size():return false
	return index==0 or MetaProgress.yuriko_school.get("gm_open",false) or MetaProgress.yuriko_school.get("read",{}).has(OUTFIT_CHAPTERS[index])

static func outfit_label(index:int) -> String:
	if index==WEDDING_OUTFIT:
		if not journal_head_unlocked():return "需先解锁手记头型"
		return "已收藏 · 手记头型专用" if owns_wedding_cg() else "收藏 CG《同一站下车》解锁"
	if outfit_unlocked(index):return "免费"
	return ["","读完第五章《靠窗第三排》解锁","读完第八章《放学以后也能找到我》解锁"][index]

static func usable_outfit(index:int) -> int:
	return index if outfit_unlocked(index) else 0

static func snapshot() -> Dictionary:
	var state:=MetaProgress.yuriko_school
	return {"points":0,"learned":state.get("learned",[]).duplicate(),"skin":usable_outfit(int(state.get("skin",0))),"affinity_bonuses":bonus_counts()}

static func can_learn(talent:Dictionary) -> bool:
	var learned:Array=MetaProgress.yuriko_school.get("learned",[])
	return talent.id not in learned and balance()>=int(talent.cost) and talent.requires.all(func(id):return id in learned)

static func learn(id:String) -> bool:
	for talent in talents:
		if talent.id==id and can_learn(talent):
			var next:=MetaProgress.yuriko_school.duplicate(true)
			next.get_or_add("learned",[]).append(id)
			return commit(next)
	return false

static func wear(index:int) -> bool:
	if not outfit_unlocked(index):return false
	var next:=MetaProgress.yuriko_school.duplicate(true)
	next.skin=index
	return commit(next)

static func cursor(ep:Dictionary) -> Dictionary:
	return MetaProgress.yuriko_school.get("marks",{}).get(ep.id,{"step":0,"answer":-1})

static func lines(ep:Dictionary,answer:int) -> Array:
	var result:Array=ep.intro.duplicate()
	if answer>=0:
		result.append_array(ep.choices[answer].lines)
		if ep.has("echo"):
			var past:int=MetaProgress.yuriko_school.get("read",{}).get(ep.echo.from,-1)
			if past in [0,1]:result.append(ep.echo.lines[past])
		if ep.has("gift_memory"):
			var memory:Dictionary=ep.gift_memory
			var given:Dictionary=MetaProgress.yuriko_school.get("given",{})
			result.append(memory.remembered if given.has(memory.gift) else memory.ordinary)
		if ep.has("invitation"):
			var invitation:Dictionary=ep.invitation
			var close_enough:=int(MetaProgress.yuriko_school.get("affinity",0))>=int(invitation.affinity)
			result.append(invitation.close if close_enough else invitation.shy)
		result.append_array(ep.outro)
	return result

static func choosing(ep:Dictionary) -> bool:
	var mark:=cursor(ep)
	return int(mark.answer)<0 and int(mark.step)==ep.intro.size()

static func advance(ep:Dictionary,answer:=-1) -> bool:
	if not available(ep):return false
	var next:=MetaProgress.yuriko_school.duplicate(true)
	var marks:Dictionary=next.get_or_add("marks",{})
	var mark:Dictionary=cursor(ep).duplicate()
	if choosing(ep):
		if answer not in [0,1]:return false
		mark.answer=answer
	elif answer!=-1:return false
	else:mark.step=int(mark.step)+1
	if int(mark.answer)>=0 and int(mark.step)>=lines(ep,int(mark.answer)).size():
		var read:Dictionary=next.get_or_add("read",{})
		if not read.has(ep.id):
			read[ep.id]=int(mark.answer)
			add_affinity(next,int(ep.get("affinity_award",0)))
		marks.erase(ep.id)
		next.erase("last")
	else:
		marks[ep.id]=mark
		next.last=ep.id
	return commit(next)

static func suggested(kind:String) -> Dictionary:
	var state:=MetaProgress.yuriko_school
	var unfinished:Dictionary={}
	var unread:Dictionary={}
	for ep in episodes:
		if ep.kind!=kind or not available(ep):continue
		if state.get("marks",{}).has(ep.id):
			if ep.id==state.get("last",""):return ep
			if unfinished.is_empty():unfinished=ep
		elif unread.is_empty() and not state.get("read",{}).has(ep.id):
			unread=ep
	return unread if unfinished.is_empty() else unfinished

static func contact_ready() -> bool:
	return MetaProgress.yuriko_school.get("read",{}).has("letter")
