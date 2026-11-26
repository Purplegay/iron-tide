extends RefCounted

const Heroes = preload("res://scripts/expedition/heroes.gd")
static var chronicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/expedition_hero_chronicles.json"))
# Each commission follows a specific existing playable field objective.
const BOOK := {
	"CLNT":{"kind": "radio", "title": "最后一段静场", "clue": "电台只传来两声敲击。克林特请你守住频道，等场记把镜头号念完。", "story": "片场停电那晚，场记还在黑暗里报号。克林特坐在收音机旁，把每个数字都记在空烟盒上。救援队要走，他却听出名单少了一声回答。", "reply": "人到齐了。烟盒留给你，我跟下一班车。"},
	"ARND":{"kind": "engineer", "title": "撑住这扇门", "clue": "一位工兵困在道具仓里，阿诺守在门边等第二套起重工具。", "story": "道具仓的卷门脱了轨。阿诺把它顶在肩上，让里面的人一个个从缝里钻出来。最后那个工兵还在找一张折叠椅。后来他才知道，椅背上有他女儿歪歪扭扭写的名字。", "reply": "椅子也带上了。你走前面，我收尾。"},
	"STLN":{"kind": "box", "title": "没拍完的撤离", "clue": "失落的黑匣子里有一段外景录音，史泰龙认出了录音师的声音。", "story": "剧本里，英雄最后一个登车。真正撤离时他早早就坐下了，膝上托着录音师的设备，空出两只手拉人。那卷磁带只录到了喘气声，却是全组唯一一条谁也不舍得剪掉的素材。", "reply": "带子收好了。还有谁没上车？"},
	"YURIKO":{"kind":"intel","title":"没有编号的回信","clue":"港区联络站的邮袋被留在中转点。百合子说，找印着半颗橘子的那张信笺。","story":"回信夹在一本电车时刻表里。百合子没有写自己的编号，只写了放学后哪几站有车，以及学校开放日卖不掉的炒面该怎么热。最后才提起正事。如果需要她，请先让她知道要去哪里，还能不能坐末班车回来。","reply":"你的信我收到了。明天总站见，我带两份早饭。"},
	"E1": {"kind":"contact", "title":"最后一班岗", "clue":"联络人的名单里少了一个名字。守望者还站在集合点，等最后一班人回来。", "story":"撤退那晚，岗亭只剩半截铅笔。他用它把过路人的名字写在门板上，每来一个就划去一个。天亮时，只剩换岗的小兵没有回来。他把自己的位置报给联络人，然后又多站了一班。", "reply":"门板上划完了。给我一个位置，这回我替你们站岗。"},
	"E2": {"kind":"radio", "title":"炉边的回音", "clue":"监听员听见有人敲饭盒。炉火和三个掉队的步兵还守着一台电台。", "story":"炉火以前给夜班的人留汤。营房的灯一熄，迟归的人便在门上敲三下。这次掉队，电台里的声音一模一样。他让身边的新兵敲响饭盒，自己守着话筒，等另一头有人认出这顿夜饭。", "reply":"锅我背着。带路吧，等人到齐就开饭。"},
	"MTNK": {"kind":"box", "title":"回程的路标", "clue":"黑匣子里有一段未送出的行车记录，末尾署名北辰。", "story":"第一次带车队进山，北辰只在地图上画了去程。雪落下来，回去的路口看起来全都一样。后来他养成一个习惯，每过一道弯都回头看一次。这只匣子里存着他沿途拍下的路口，镜头全朝着家的方向。", "reply":"记录送到了？那就上车。下一程我们一起认路。"},
	"HTNK": {"kind":"contact", "title":"车尾的座位", "clue":"联络人拿着一张乘员表。铁脊一直给失散的引导员留着座位。", "story":"车组给每个座位都缝了布套，唯独引导员的那只一直空着。有人提议拿来放工具，铁脊摇头。每晚停车，他都擦一遍车尾的扶手。引导员喜欢从那里爬上来，不喜欢别人伸手去拉。", "reply":"他上车了。告诉你们的车队，最后一辆交给我。"},
	"TANY": {"kind":"radio", "title":"第三声才回答", "clue":"谭雅认出了失联小队的呼号。她请你先核对识别码，再把人接回来。", "story":"录音里，有人在报完呼号后吸了一口气。谭雅把那一秒听了三遍。她记得教这个新兵发报时，对方总是一紧张就忘了呼吸。现在那孩子终于学会了，她想亲口告诉他。", "reply":"人齐了。下次频道里听见我，记得回答。"},
	"BORIS": {"kind":"divert", "title":"没有署名的电报", "clue":"鲍里斯在中继台等回音。他要确认敌方通讯车已经离开这条路。", "story":"一封迟到的家书跟着车队转了三站，信封上只写着旧哨所的门牌。鲍里斯认识那个地方。他把信揣进口袋，坐在中继台旁等路空出来。信里是什么，他一直没拆。", "reply":"路通了。信我会送到，回程到你营地报到。"},
	"ORCA": {"kind":"fuel", "title":"留一盏地灯", "clue":"游隼还在云层上盘旋。她只认前哨站的地灯，得把油罐车护送到站。", "story":"第一次独自返航，游隼把海上的倒影当成了跑道。有人在地面摇动手灯，一短一长，把她引回岸边。这些年她换过几个机场，飞行簿第一页始终夹着那块地勤袖章。今晚她又在等那束光。", "reply":"我看见灯了。下一次出航，把我的呼号也写上。"},
	"TTNK": {"kind":"box", "title":"断掉的一拍", "clue":"黑匣子记下了一段异常读数。雷铸想把这份原始记录带回车间。", "story":"试车时，雷铸听出线圈的嗡鸣漏了一拍。仪表却说一切正常。他答应值夜的学徒，等记录送回来，两个人就从第一行重新看起。那晚之后，车间的墙上多了一张纸，谁听见异响都可以写名字。", "reply":"学徒听对了。图纸留给车间，我跟你们去听下一台。"},
	"FV": {"kind":"engineer", "title":"给桥留个名字", "clue":"受困工兵带着桥梁勘测簿。引片在撤离点等他带回原件。", "story":"引片给车里的每件工具都刻过编号，却记不住一路走过的桥名。一次撤离后，工兵翻开手里的勘测簿，里面除了跨度，还写着当地人对每座桥的叫法。从那以后，引片总把副驾的位置留给记笔记的人。", "reply":"本子和人都在。下一座桥，我来开车。"},
	"HARV": {"kind":"fuel", "title":"一车的分量", "clue":"老秤已经在停靠点铺好油管。他要整车送达，才肯随队出发。", "story":"老秤的车门背面画着一道道短线。新人以为是运回的车数，他说那是一路搭过车的人。今天门上又添了一道，给那位坚持把最后一车油送进站的司机。", "reply":"油交清了，人也到了。给我排个班吧。"}
}

const REUNIONS := {
	"E1/MTNK":"守望者把门板上的名单递进车窗。北辰数了一遍，在地图上圈出最后一个接人点。",
	"TANY/ORCA":"游隼在频道里敲了三下。谭雅笑着应了一声。这一次，地面和空中都听清了。",
	"FV/MTNK":"引片念出桥的老名字，北辰把它写在回程的箭头旁。两本路书第一次对上了页码。",
	"E2/HTNK":"炉火数完饭盒，多留了一份。铁脊朝车尾招招手，空着的座位终于有人回应。",
	"BORIS/TTNK":"雷铸陪鲍里斯找到旧哨所。门铃早就坏了，他们轮流敲门，直到里面有人答话。",
	"HARV/E2":"老秤问这一锅有多重。炉火递给他一只碗，让他先尝尝今天大家能不能吃饱。"
}

static func reunion(a: String, b: String) -> String:
	return REUNIONS.get(a + "/" + b, REUNIONS.get(b + "/" + a, ""))

static func candidate(run: Dictionary, kind: String) -> String:
	if not run.has("country") or int(run.get("stage", 1)) >= 30:
		return ""
	if kind == "intel" and not run.get("yuriko_recruited",false) and preload("res://scripts/units/yuriko_school.gd").recruit_ready(): return "YURIKO"
	for id: String in Heroes.available(run):
		if BOOK.has(id) and BOOK[id].kind == kind:
			return id
	return ""

static func assign(run: Dictionary, objectives: Array) -> void:
	for index in range(objectives.size() - 1, -1, -1):
		var objective: Dictionary = objectives[index]
		var id := candidate(run, objective.kind)
		if not id.is_empty():
			objective.hero_lead = id
			break
	var assigned: Array[String] = []
	for objective: Dictionary in objectives:
		var best := {}
		var best_count := 1000
		for id: String in Heroes.owned(run):
			if not chronicles.has(id) or id in assigned or id in Heroes.wounded(run):continue
			var read: Dictionary = MetaProgress.hero_story_archive.get(id, {}).duplicate()
			read.merge(run.get("hero_story_archive", {}).get(id, {}))
			if read.size() >= best_count:continue
			var chapters: Array = chronicles[id].chapters
			for i in chapters.size():
				var chapter: Dictionary = chapters[i]
				if read.has(str(i+1)) or int(chapter.cycle) > int(run.get("cycle", 1)) or chapter.kind != objective.kind:continue
				best = {"hero":id, "chapter":i+1}
				best_count = read.size()
				break
		if not best.is_empty():
			objective.hero_chronicle = best
			assigned.append(best.hero)

static func chapter_for(mark: Dictionary) -> Dictionary:
	var chapters: Array = chronicles.get(mark.get("hero", ""), {}).get("chapters", [])
	var index := int(mark.get("chapter", 0)) - 1
	return chapters[index] if index >= 0 and index < chapters.size() else {}

static func chapter_hint(mark: Dictionary) -> String:
	var chapter := chapter_for(mark)
	return "%s ·《%s》　%s" % [name_of(mark.hero), chapter.title, chapter.clue]

static func settle(run: Dictionary, objectives: Array, report: Dictionary) -> void:
	for objective: Dictionary in objectives:
		var id := str(objective.get("hero_lead", ""))
		if not objective.get("done", false) or objective.get("failed", false):
			continue
		if objective.kind == "fuel" and objective.get("phase", "") != "station":
			continue
		if objective.has("hero_chronicle"):
			record_chapter(run, objective, report)
		if id == "YURIKO" and objective.kind == "intel" and not run.get("yuriko_recruited",false):
			run.yuriko_recruited = true
			report.get_or_add("field_heroes", []).append(id)
			continue
		if not id.is_empty() and candidate(run, objective.kind) == id and Heroes.recruit(run, id):
			report.get_or_add("field_heroes", []).append(id)
			for other: String in Heroes.owned(run):
				var dialogue := reunion(other, id)
				if not dialogue.is_empty():
					report.hero_reunion = dialogue

static func record_chapter(run: Dictionary, objective: Dictionary, report: Dictionary) -> void:
	var mark: Dictionary = objective.hero_chronicle
	var chapter := chapter_for(mark)
	if chapter.is_empty() or chapter.kind != objective.kind or int(chapter.cycle) > int(run.get("cycle",1)):return
	var id: String = mark.hero
	if id not in Heroes.owned(run):return
	var key := str(int(mark.chapter))
	var pages: Dictionary = run.get_or_add("hero_story_archive", {}).get_or_add(id, {})
	if pages.has(key) or MetaProgress.hero_story_archive.get(id, {}).has(key):return
	const Portraits = preload("res://scripts/ui/hero_portraits.gd")
	if id in Portraits.DRIVER_IDS and pages.is_empty() and not Portraits.driver_unlocked(id):
		report.get_or_add("driver_portrait_rewards", []).append(id)
	pages[key] = {"cycle":int(run.get("cycle",1)), "stage":run.stage}
	report.get_or_add("hero_chronicles", []).append(mark.duplicate())

# Publish only chapters from a committed expedition. Reopening that run retries a failed profile write.
static func deliver(run: Dictionary) -> bool:
	var pending: Dictionary = run.get("hero_story_archive", {})
	if pending.is_empty():return true
	var merged := MetaProgress.hero_story_archive.duplicate(true)
	var changed := false
	for id: String in pending:
		var pages: Dictionary = merged.get_or_add(id, {})
		for key: String in pending[id]:
			if pages.has(key):continue
			pages[key] = pending[id][key]
			changed = true
	if not changed:return true
	var previous := MetaProgress.hero_story_archive
	MetaProgress.hero_story_archive = merged
	if MetaProgress.save():return true
	MetaProgress.hero_story_archive = previous
	return false

static func name_of(id: String) -> String:
	return "百合子" if id == "YURIKO" else MetaProgress.Academy.HEROES[id]
