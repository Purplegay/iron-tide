extends RefCounted

const REUNIONS := preload("res://scripts/expedition/keepsake_reunion_stories.gd").STORIES
const MAX_RANK := 5
const ICON_TILES := {"vera":0,"volkov":1,"lin":2,"su":3,"mara":4,"nadya":5,"qiao":6,"ines":7,"edith":8,"sami":9,"greta":10,"seojin":11,"yusuf":12}
const ICON_SHEET := preload("res://assets/ui/keepsakes.svg")
static var _icons:Dictionary={}

static func icon(id:String) -> Texture2D:
	if not ICON_TILES.has(id):return null
	if not _icons.has(id):
		var tile:=AtlasTexture.new()
		tile.atlas=ICON_SHEET
		tile.region=Rect2(int(ICON_TILES[id])*64,0,64,64)
		tile.filter_clip=true
		_icons[id]=tile
	return _icons[id]

static func icon_view(id:String) -> TextureRect:
	var view:=TextureRect.new()
	view.texture=icon(id)
	view.custom_minimum_size=Vector2(32,32)
	view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return view

const ITEMS := {
	"greta":{
		"name":"打孔的绿货票","partners":["TNKD","HTNK"],"order":"西站换班",
		"guide":"点按钮为全图己方地面作战车辆换班，当前剩余装填时间减半，随后 10 秒内新开始的主武器装填时间也减半。坦克杀手和犀牛坦克同时在场时，当前装填立即完成。冷却 600 秒。",
		"gift":"《拇指穿过去》\n格蕾塔拿给我一叠绿货票，让我闭眼从中间抽出原件。纸比我想的厚，只有一道圆孔的边缘已经磨得很软。她说那是几十班人交接时用拇指摸出来的。\n我睁开眼，她已经把其余的票收走了：“这张给你。下回换你接班。”",
		"after":"《交班簿》\n两名车长在交班簿上同一行签了字。格蕾塔刚想让他们一人占一行，又把尺子收起来。师父以前说过，有些活非得两个人在场，账才算得清。"},
	"seojin":{
		"area":{"radius":300},
		"name":"橙白相间的旧风袋","partners":["BEAG","ORCA"],"order":"云雀轰炸",
		"guide":"点地呼叫四架飞机依次轰炸半径 {radius} 的区域。每架对圈内可见的敌方地面部队和建筑造成 120 基础伤害。黑鹰与入侵者同时在场时，每架提高到 180。冷却 600 秒。",
		"gift":"《袖口那么长》\n瑞珍把拆下来的风袋卷在我的手腕上，原来收拢后只有袖口那么长。她指着那个颜色最鲜的补丁，说只有这一段没在风里多待过，是师傅最近才补的。\n“旧布也能替新飞行员认路。”她系紧带子，把结留在我另一只手够得着的地方。",
		"after":"《两本航迹簿》\n黑鹰报完油量，入侵者接着报天气，塔台抄着抄着换错了记录本。瑞珍把两页沿着雨印拼在一起，两条线恰好从同一面风袋底下经过。"},
	"yusuf":{
		"name":"绿门车场的铜钥匙牌","partners":["DTRUCK","HARV"],"order":"签收运费",
		"guide":"点击签收，立即获得 {base} 战场资金。场上每辆己方矿车额外提供 {bonus} 资金。冷却 600 秒。己方利比亚自爆卡车和武装采矿车同时在场时，本次总收入翻倍，冷却缩短至 240 秒。",
		"gift":"《留给末车》\n优素福把钥匙摘走，铜牌交给了我。牌上是一扇只漆了一半的门。他说钥匙归司机，牌归等车的人，回来时要让两样东西碰一下才算交班。\n我问他碰响了是不是就能下班。他看看炉子：“还得记得把饭端走。”",
		"after":"《一张合单》\n两辆车一前一后驶过绿门，账房开了两张收条，司机却只肯领一份热饭。优素福揭开锅盖看看，给一份饭盛了两大勺，在合单上盖了个油乎乎的拇指印。"},
	"edith":{
		"area":{"radius":320,"reveal":560},
		"name":"缺一只眼罩的望远镜","partners":["SNIPE","FV"],"order":"苇塘守望",
		"guide":"点地标记半径 {radius} 内的敌军和建筑，持续追踪 30 秒，每个目标脚下的一格随它移动而亮起。英国狙击手与多功能步兵车同时在场时，额外照亮落点周围半径 {reveal} 的区域 10 秒。冷却 600 秒。",
		"gift":"《空出来的那一边》\n伊迪丝把望远镜交给我，左边没有眼罩。我问要不要等小姑娘用完，她摇摇头，从衣袋里掏出一张盖满泥圈的纸。最后一个圈是空的。\n“她说头回借你，得让你自己挑样东西画。”伊迪丝把铅笔也递过来，“画歪了就歪了，鸟可不认得自己该长什么样。”",
		"after":"《换班那一分钟》\n狙击手数到第三只水鸟就得上车。车里的人接过镜子，等到第四只从芦苇后头领出两只小的，才在纸上记了个六。交班时两人谁都没提自己数了几只。\n伊迪丝在观察者那一格拆了条竖线，让他们一人签一边。"},
	"sami":{
		"area":{"radius":260},
		"name":"刻零的搪瓷量杯","partners":["DESO","SENGINEER"],"order":"泵站点验",
		"guide":"点一处地面，为半径 {radius} 内受损的己方地面作战步兵和载具恢复 20% 最大生命。瞄准时，可治疗的部队脚下会闪烁绿圈。伊拉克辐射工兵与苏军工程师同时在场时恢复 40%。空地也可施放，确认后冷却 600 秒。",
		"gift":"《杯耳朝外》\n萨米递来那只量杯。杯底的零歪向一边，倒扣时怎么摆都不正。他妹妹伸手把杯耳转向我，说这样戴着手套的人也能一下拿住。\n“以前我教她看刻度，”萨米说，“现在她教我，递东西要看看另一头的手。”",
		"after":"《交回来的杯子》\n清点时，工兵扶着那个一直说自己还能走的司机坐下，工程师去把漏水的龙头拧紧。等司机喝完，萨米才在他名字后面打勾。\n最后一个人把杯子递回来，杯耳正朝着萨米的手。他妹妹隔着半个院子看见了，没出声，笑了一下。"},
	"vera":{
		"area":{"radius":300},
		"name":"变电所最后一把钥匙","partners":["TTNK","SREF"],"order":"合闸",
		"guide":"点「合闸」，再左键点地面召下闪电，电击半径 {radius} 内可见的敌方地面单位和建筑。右键取消。己方磁暴坦克和光棱坦克同时在场时，落雷命中敌军即可获得战记。冷却 600 秒。",
		"gift":"《钥匙认人》\n小徒弟从工作服里摸出一把钥匙，柄上还拴着病房的蓝布条。维拉问他舍不舍得。他说配钥匙的铺子上礼拜开张了，掏出一串新钥匙，挨个试给我们听。最后那把旧的落在我手里，还有他的体温。\n维拉把我的手指合上：“上次你把拿钥匙的人救出来了。这次，换你合闸。”",
		"after":"《合闸的人》\n闪电照亮变电所的窗户，小徒弟低头在值班表上找了半天，说还缺一个签名。维拉把表推过来。我签得歪，他也没擦，只在下面写：今夜送电，全班到齐。"},
	"volkov":{
		"area":{"radius":260},
		"name":"缺齿炮闩","partners":["TNKD","APOC"],"order":"扳动炮闩",
		"guide":"点地炮击半径 {radius} 内可见的敌方地面部队和建筑，造成 320 基础伤害。坦克杀手与天启坦克同时在场时提高到 480。冷却 600 秒。",
		"gift":"《第三声》\n米沙把旧炮闩压在调拨单上。钢上缺了一齿，长官肯定嫌它难看。沃尔科夫却说，车里最黑的时候，戴手套一摸就知道哪头朝前。\n他在我桌面敲了两下。我等了一会儿，隔壁车库果然传来第三下。他把炮闩推给我：“这回听见了。给你。”",
		"after":"《合奏》\n德国车长在电台里喊了一声准，天启的炮手们齐声回答。米沙拿铅笔在值班表上画了根五线谱，几个音符全挤在同一拍。老头挑了半天毛病，最后只说：少画了人家起头的那个。"},
	"lin":{
		"area":{"radius":260,"blast":160},
		"name":"遮阳板乘客名单","partners":["CLEG","APOC"],"order":"接人",
		"guide":"点地救援半径 {radius} 内最多四名己方步兵或作战车辆，优先救生命比例最低者。白圈标出获救部队。确认后护盾抵挡伤害，5 秒后，每名获救单位在脚下引爆护盾，对半径 {blast} 内的敌方地面单位和建筑造成 240 基础伤害，随即撤回基地附近空地。超时空军团兵在场时，有武器的部队在撤离处留下残影，向附近敌人打两轮。冷却 600 秒。",
		"gift":"《还有四个空位》\n林岚递来一块旧遮阳板。上回写在背面的名字都打了勾，最下面却多出四行，用橡皮擦过一遍，又描得整整齐齐。\n“别等出事才填。”她把铅笔塞进弹簧夹，“你出发前就写。我走到哪一站，知道该等几个人。”",
		"after":"《回车铃》\n车已经停稳，远处又响起主炮声。小满从副座上跳起来，数了一遍人头，又数一遍。林岚把他按回座位，指着那些姓名：“听见的是刚才的他们。现在这一车，归你点名。”"},
	"su":{
		"name":"双曝光底片","partners":["SREF","TTNK"],"order":"二次曝光",
		"guide":"点击后获得全图视野 4 秒，全图敌军单位和建筑每秒受到 30 点基础灼烧伤害。光棱与磁暴同时在场时伤害翻倍。冷却 600 秒。",
		"gift":"《漏光的暗袋》\n苏砚从显影盘里夹起两张叠在一起的人像。第一张是个浑身泥的工兵，第二张是他洗过脸以后，耳朵后面还漏了一块。研究所嫌重影，他把照片留了下来。\n“别人看得见挨了几炮，我想看清第一炮到底帮了第二炮多少忙。”他把那只暗袋交给我。",
		"after":"《两次快门之间》\n显影纸上第一道白痕刚好贴着第二道的边。苏砚把两支车组的名字都写进署名栏，把自己的名字挪到背面。我翻过来，看见一行小字：洗照片的，今晚留下擦桌子。"},
	"mara":{
		"area":{"radius":145},
		"name":"灯塔的红绿玻璃","partners":["ORCA","BEAG"],"order":"引航灯列",
		"guide":"点地面呼叫入侵者，或按住左键锁定中间的轰炸圈，拖动调整航向，松开呼叫。飞机沿箭头依次轰炸三个半径为 {radius} 的圆圈，每枚航标弹造成 240 基础伤害。己方入侵者和韩国黑鹰同时在场时，黑鹰从反方向再投三枚。冷却 600 秒。",
		"gift":"《给归船留一面》\n玛拉拆下灯罩，把红玻璃递到我左手，绿玻璃递到右手。她父亲教她认方向从来不说左右，只问，回家的船从这里看，应该是什么颜色。\n她退到营地门外，让我给她指一次路。看我没拿反，她才把两块玻璃装进小盒。",
		"after":"《交班》\n两队飞机在灯列两端报了平安。年轻的飞行员问塔上是谁领航，玛拉把麦克风递给我。那头传来笑声：“我认得你的灯。绿色那盏，比红的晃得厉害一点。”"},
	"nadya":{
		"name":"慢五秒的钟摆","partners":["HTK","FV"],"order":"借来五秒",
		"guide":"点击后打断全图敌方地面部队的连射，将其开火冷却延长至至少 5 秒。战争迷雾中的敌军也会受到影响。己方防空履带车与多功能步兵车同时在场时，5 秒后对全图敌方地面部队各造成一次 380 基础伤害。冷却 600 秒。",
		"gift":"《报时误差》\n修钟师说钟楼慢了五秒。娜佳不肯调：楼下那个卖报的孩子，每天就靠这五秒赶上第一班车。\n她给新钟装了准点的摆，把旧摆包好送我。“什么时候差一口气，你就朝我借。那孩子现在自己开车了。”",
		"after":"《末班车》\n两个车组在同一拍接了话。娜佳以为自己拨错频率，听了半天才发现，两个国家的小伙子都在用嘴学那声钟响。她按下通话键，也学了一声。"},
	"qiao":{
		"area":{"half_width":80,"wide_half_width":120},
		"name":"磨白的木折尺","partners":["GGI","V3"],"order":"沿尺开路",
		"guide":"点地面空降犀牛坦克，或按住左键拖动车头朝向，松开投放。坦克沿箭头碾过亮带，冲到尽头后撤离。对敌建筑造成双倍伤害。碾压带从中心线向两侧各延伸 {half_width}，第三周目起各延伸 {wide_half_width}。己方重装大兵和 V3 发射车同时在场时，碾中敌军即可获得战记。冷却 600 秒。",
		"gift":"《折过去的半寸》\n乔远的尺上少了半寸刻度。小时候他拿它量门框，妹妹一年比一年高，最高的那道铅笔印被拇指磨没了。他从没舍得换。\n交给我时他折起第一节：“量桥用后面几节。这一节，到家还得量人呢。”",
		"after":"《尺的另一头》\n烟散开时，履带印从桥头一直铺到对岸。重装大兵和发射车司机各自举起尺的一头，隔着空地争是谁站歪了。乔远只忙着拍照：“吵，使劲吵。以前这里两边的人喊都听不见。”"},
	"ines":{
		"area":{"radius":300,"reveal":375,"chain":210},
		"name":"背面朝外的袖镜","partners":["MGTK","HTK"],"order":"镜面伏击",
		"guide":"点地面侦照半径 {reveal} 的区域，标记半径 {radius} 内的敌军，随后逐个伏击。幻影坦克和防空履带车同时在场时，每个标记再伏击其周围半径 {chain} 内的另一名敌军。冷却 600 秒。",
		"gift":"《镜子朝外》\n伊内丝的袖口缝着一面镜子，镜背朝外。她说小时候站在窗口给弟弟打信号，闪一下是车来了，闪两下是再睡一会儿。后来侦察队人人会读，弟弟倒总要装睡。\n她替我扣好袖扣：“想让人知道你在哪儿，再翻过来。”",
		"after":"《多闪一下》\n雨燕的两列车顺着镜光同时现身，电台里的口哨响成一片。清点完毕，伊内丝往空路口又闪了一下。我问那是什么意思。她收起镜子：“告诉在家等的人，可以再睡一会儿。”"}
}

static func previous_rescues(meta) -> Array:
	var cleared:=false
	for key:String in meta.settled_matches:
		if key.begins_with("expedition:") and key.ends_with(":"+str(preload("res://scripts/expedition/campaign.gd").TOTAL)):
			cleared=true
			break
	var names:Array=[]
	if cleared:
		for id:String in ITEMS:
			if meta.contact_transcripts.get(id,{}).get("rescued",false):names.append(id)
	return names

static func owned(id:String) -> bool:
	return ITEMS.has(id) and MetaProgress.contact_transcripts.get(id,{}).has("keepsake")

static func can_equip(run: Dictionary, id: String) -> bool:
	if run.get("phase", "") != "ready" or not owned(id) or id in carried(run):
		return false
	if id not in run.get("reunion_contacts", []):
		return false
	for report: Dictionary in run.get("battle_reports", []):
		if id in report.get("met_contacts", []):
			return true
	# Existing runs retain their completed rescues in the support roster.
	for person: Dictionary in run.get("field_contacts", []):
		if person.id == id:
			return true
	return false

static func rank(id: String) -> int:
	if not owned(id):return 0
	return mini(MAX_RANK, 1 + MetaProgress.contact_transcripts[id].get("keepsake_upgrades", []).size())

static func receipts(id: String) -> Array:
	if not owned(id):return []
	var entry: Dictionary = MetaProgress.contact_transcripts[id]
	return [entry.keepsake] + entry.get("keepsake_upgrades", [])

static func story(id: String, level: int) -> String:
	return ITEMS[id].gift if level == 1 else REUNIONS[id][level - 2]

static func eligible(id: String, run: Dictionary, met_contacts: Array) -> bool:
	if id not in met_contacts or id not in run.get("reunion_contacts", []) or not ITEMS.has(id):return false
	var level := rank(id)
	if level == 0:return true
	if level >= MAX_RANK:return false
	var entry: Dictionary = MetaProgress.contact_transcripts[id]
	var last: Dictionary = entry.keepsake if level == 1 else entry.keepsake_upgrades.back()
	return run.id != last.get("run", "") and int(run.get("cycle", 1)) > int(last.get("cycle", 1))

static func migrate_cycles(meta) -> bool:
	var changed := false
	var current := preload("res://scripts/expedition/cycle_letters.gd").cycle(meta.settled_matches, preload("res://scripts/expedition/campaign.gd").TOTAL)
	for id: String in ITEMS:
		var entry: Dictionary = meta.contact_transcripts.get(id, {})
		if not entry.has("keepsake") or entry.keepsake.has("cycle"):continue
		var old_run: String = entry.keepsake.get("run", "")
		var finished: bool = meta.settled_matches.has("expedition:%s:%d" % [old_run, preload("res://scripts/expedition/campaign.gd").TOTAL])
		entry.keepsake.cycle = maxi(1, current - 1) if finished else current
		changed = true
	return changed

static func inscribe(id:String,run:Dictionary,first_use:bool,met_contacts:Array=[]) -> bool:
	if not ITEMS.has(id) or str(run.get("id","")).is_empty():return false
	var entry:Dictionary=MetaProgress.contact_transcripts.get(id,{})
	var key:="joint_record" if first_use else "keepsake"
	if first_use:
		if entry.has(key) or not owned(id):return false
	elif not eligible(id, run, met_contacts):return false
	var receipt := {"run":run.id, "stage":run.stage, "cycle":int(run.get("cycle", 1)), "date":Time.get_date_string_from_system()}
	var updated := entry.duplicate(true)
	if not first_use and owned(id):
		updated.get_or_add("keepsake_upgrades", []).append(receipt)
	else:
		updated[key] = receipt
	MetaProgress.contact_transcripts[id] = updated
	if MetaProgress.save():return true
	MetaProgress.contact_transcripts[id] = entry
	return false

const SLOT_CYCLES := [2, 4, 6, 11]

static func slot_limit(cycle:int) -> int:
	var limit:=0
	for threshold:int in SLOT_CYCLES:
		if cycle>=threshold:limit+=1
	return limit

static func slot_hint(cycle:int,count:int) -> String:
	var limit:=slot_limit(cycle)
	var text:="第 %d 周目 · 出发信物已选 %d / %d 件"%[cycle,count,limit]
	if limit<SLOT_CYCLES.size():text+=" · 第 %d 周目出发可带 %d 件"%[SLOT_CYCLES[limit],limit+1]
	return text

static func carried(run:Dictionary) -> Array:
	if run.has("keepsakes"):return run.keepsakes
	var legacy:String=run.get("keepsake","")
	return [legacy] if ITEMS.has(legacy) else []

# Zero-based slot. Each successive gap grows by ten battle seconds.
static func cooldown_seconds(base:int, run:Dictionary) -> int:
	var rank := clampi(preload("res://scripts/expedition/relics.gd").level(run,"signal_timer"),0,5)
	return roundi(base * (10 - rank) / 10.0)

static func use_cooldown(base: int, id: String, run: Dictionary) -> int:
	return roundi(cooldown_seconds(base, run) * (10 - maxi(0, rank(id) - 1)) / 10.0)

static func area_at_rank(id: String, level: int) -> Dictionary:
	var base: Dictionary = ITEMS[id].get("area", {})
	var area := {}
	var steps := clampi(level, 1, MAX_RANK) - 1
	for key: String in base:
		area[key] = roundi(int(base[key]) * (10 + steps) / 10.0)
	return area

static func freight_rates(level: int) -> Dictionary:
	var scale := 9 + clampi(level, 1, MAX_RANK)
	return {"base":500 * scale, "bonus":100 * scale}

static func guide_for_run(id:String,run:Dictionary) -> String:
	var guide:String=ITEMS[id].guide
	var level := maxi(1,rank(id))
	var progress := "已满档" if level == MAX_RANK else "每个新周目重逢可升一档"
	if id == "yusuf":
		guide = guide.format(freight_rates(level))
		if level < MAX_RANK:
			progress += " · 每升一档，基础运费加 500，每辆矿车多加 100"
	var area := area_at_rank(id,level)
	if not area.is_empty():
		guide = guide.format(area)
		if level < MAX_RANK:
			progress += " · 每档增加基础范围的 10%"
	return "信物 %d/%d 档 · %s\n" % [level, MAX_RANK, progress] + guide.replace("240 秒", "%d 秒" % use_cooldown(240,id,run)).replace("600 秒", "%d 秒" % use_cooldown(600,id,run))

static func opening_cooldown(slot:int, run:Dictionary = {}) -> int:
	return cooldown_seconds(mini(300, 5 * slot * (slot + 1)),run)
