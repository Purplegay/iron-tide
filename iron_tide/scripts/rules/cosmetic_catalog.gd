extends RefCounted
const Styles = preload("res://scripts/units/unit_cosmetics.gd")
const EXCLUSIVE_SKINS := {"TNKD":"casemate_frame","HARV":"night_shift","NAREFN":"night_shift","MTNK":"cobalt_porcelain","HTNK":"ember_steel","SREF":"corona_glass","GGI":"cliff_sentry","TTNK":"amber_coils","APOC":"polar_observatory","SCHP":"obsidian_night_owl","DRON":"rift_hunter"}
const SKIN_NAMES := {"casemate_frame":"猎隼外骨骼","night_shift":preload("res://scripts/units/night_shift.gd").NAME,"cobalt_porcelain":"钴蓝白瓷","ember_steel":"余烬重钢","corona_glass":"日冕玻璃","cliff_sentry":"岸防导弹手","amber_coils":"皮卡丘 · 雷霆机甲","polar_observatory":"北境天文台","obsidian_night_owl":"黑曜夜枭","rift_hunter":"缝隙猎蛛"}
const SKIN_MATERIALS := {"winter":2,"night_shift":3,"cobalt_porcelain":4,"ember_steel":5,"corona_glass":6,"cliff_sentry":7,"amber_coils":8,"polar_observatory":9}
const WEAPON_FX := {
	"TTNK":"spectrum","SHK":"spectrum","TESLA":"spectrum","R3TESLA":"spectrum","R3APOC":"blue_arc",
	"FLAKT":"pixel_blast","HTK":"pixel_blast","HYD":"pixel_blast","NAFLAK":"pixel_blast","SREF":"duplex","NABNKR":"cyber_hit",
	"APOC":"molten_duet","CLEG":"time_fracture","V3":"reentry","DRED":"reentry",
	"SUB":"quiet_sonar","TERROR":"love_peace","DTRUCK":"love_peace"
}
const WEAPON_NAMES := {"molten_duet":"熔芯双响","time_fracture":"时间断层","reentry":"再入流星","quiet_sonar":"静默声呐","blue_arc":"蓝电回旋","spectrum":"虹彩电弧","pixel_blast":"像素 BLAST","duplex":"蓝红交替","cyber_hit":"赛博指针 HIT","love_peace":"LOVE & PEACE · 爱心爆破"}
const EFFECT_TEXT := {
	"obsidian_night_owl":"原版大小的精细黑钢机体、玻璃座舱与阵营色饰边，32 向转身、独立旋翼和飞行气流；部署时支脚展开、火炮伸出，撤收时反向收拢。琥珀灯在游戏中持续呼吸。",
	"rift_hunter":"分层黑钢背甲、阵营色膝甲与银钢机械关节，四足随真实移动交替迈步、32 向转身；红灯在游戏中持续呼吸，寄生隐藏时一起消失。外观为原版的 140%，碰撞与战斗数值保持原规则。",
	"casemate_frame":"两侧贴身护板各嵌两根凸起圆管，共四根，每根由前中后三道带螺钉的金属抱箍扣住。每块板上红蓝各一根，左右配色相反。侧灯约五秒完成一次明暗呼吸，玻璃护套内可见细绕线和亮芯。四路红蓝插管从固定主炮根部交错绕到炮口，穿过三道金属锁环，炮上的四根主灯管各自错拍，先强跳、再弱跳。炮管和侧灯均带随亮度变化的柔光外晕。选中或交火时持续律动，未选中且脱战后用 3 秒放慢并定格。侧灯各自停色约 3 秒，再错开渐变互换。车尾涡轮可见内凹叶轮和隔热环，起步时叶轮高速旋转，三股蓝白火焰绕喷口一圈后汇成紧贴车尾的短粗蓝焰，转弯时焰尾随弯偏移，停车开炮时尾焰熄灭，两侧和炮管的灯在开火、装填期间持续发光；车顶双目测距仪嵌入青蓝镀膜镜片，随固定战斗室转动。",
	"rangefinder":"双目测距仪贴在棱镜炮后上方。镜筒护板跟随阵营色，金属边框随冰蓝涂装变色；两枚青蓝镀膜镜片随炮身转向，隐身时与车体一起淡出。未解锁试穿与装配使用相同配色。主炮射程内有己方可见的敌人时，镜片与镜圈亮起青光，仅操控者可见。",
	"wind_crown":"镀膜观测镜嵌在顶甲轴承内，三片橄榄绿后掠鳍带红色识别条与磨亮钢边，分别指向三门榴弹炮。某门炮的射界内出现己方可见地面敌人时，对应整片鳍从根部到尖端亮起橙金光。分区射击时，分配的侧鳍也会点亮，仅操控者可见。",
	"phase_case":"起步时，后甲双喷口依次拉出固定蓝白色的离子尾流。白热焰芯向后渐淡，两侧蓝色气流错拍卷动。行驶转弯和原地掉头时，焰根均跟随喷口，焰尾拖向转弯前的方向；恢复直行后拉直，停车时逐束收短、熄灭。",
	"slag_chains":"两侧后挡泥板各拖一条锈蚀锻钢链，焊接链座残留旧红漆，链锤下沿被地面磨出银亮拖痕。行驶时末端链节和链锤沿地面滑行，转弯时滞后甩动，刹停后受摩擦停稳。磁力研磨贴住目标时链锤烧红。",
	"corona_glass":"烟色车壳上的暗红太阳血脉沿装甲分叉，停车时从侧裙向发射座逐段泛金，开炮时从座圈向外回闪。发射座托起三段带刻度的黄铜弧环，中央留一枚亮点。停车时三片镜面依次点亮，六片拉丝金箔随环展开；开火时环面向外张开，行驶时收拢。开炮时薄棱镜在炮口展开，实际折射命中时碎光沿该束光线收拢。",
	"cliff_sentry":"双目镀膜测距镜配有海军蓝陶甲、象牙白护角和铜芯斜向散热口。行军时镜筒收在背架上，部署时横梁向两侧展开、镜筒前伸。行军时测距架随步伐左右轻摆，转身时略微滞后再回正。部署后撑脚落地，镜头随扇扫轻摆。青色扇扫和测距回波沿发射方向移动；发射时双支臂亮起橙灯，筒尾排出短焰和烟环。阵地受击时脚灯短暂闪烁。",
	"amber_coils":"柠檬黄装甲配黑尖耳形电极和红颊电容，炮塔转向时能看到皮卡丘面甲。后甲挂着闪电尾板，充能时红颊发亮，开火瞬间双耳间跳出金白电弧。",
	"polar_observatory":"移动或攻击时冰蓝星环展开，彗光沿外环巡行。持续交火时装填也保持全环，停车脱战后随最后的星光消退而渐渐收回。第一门地炮点亮引星，第二门接续开火时七星在车顶上空依次连线，随后渐隐；黄铜刻度片随双炮后坐，对空发射时侧架三盏橙灯随发射闪亮。",
	"winter":"白灰与冰蓝迷彩沿原模型的明暗分布，阵营色仍清晰可辨。",
	"cobalt_porcelain":"白瓷装甲不时闪出菱形星光；持续行驶约 8 秒后，车身完全晶化为青蓝色。停车后逐渐褪回白瓷，满晶化约 4 秒褪尽；中途起步会从当前程度继续晶化。",
	"ember_steel":"行军时沙土绕着车身旋转，停车后落下；被炮弹击中时，装甲表面掠过一道金属护壁。",
	"ice":"车身和武器换上冰蓝冷色，保留原有明暗和阵营标记。",
	"crystal":"冰蓝光晕沿棱柱外缘向外渐淡，贴近棱线处呈青白色，晶尖闪出星芒，五颗菱形碎晶错落浮起后渐隐。",
	"angel":"一对浅色羽翼悬在车体两侧，随车移动并轻轻扇动。",
	"demon":"一对暗红色尖翼悬在车体两侧，扇动时露出锯齿形翼缘。",
	"chevron_track":"行驶时留下两道箭纹车辙；停稳后，一支羽箭落在离车最远、尚未消失的本车箭纹上，扎入土中，箭尾轻颤后淡出。",
	"spectrum":"开火时，彩虹色电弧从放电端折向目标，沿着电流路径变换颜色。",
	"blue_arc":"主炮喷出带粒子的蓝焰与尾烟。命中后，蓝色火环贴地燃起，升起的热浪扭曲附近建筑表面，随后渐隐。",
	"pixel_blast":"炮弹命中时炸出像素碎片，爆心亮起 BLAST 字样。",
	"duplex":"主光束在蓝、红两色之间逐发交替；折射光束沿用本发颜色，命中处迸出碎晶。",
	"cyber_hit":"驻军射击命中时，目标身上闪出赛博鼠标指针和 HIT 字样。",
	"molten_duet":"双炮先后命中时，第一发打出暗红裂纹，第二发将裂纹点亮成金色，并升起一朵小蘑菇云。",
	"time_fracture":"擦除光束拉出青白残影，目标旁的时钟显示剩余时间；擦除成功后，原地留下一道钟印。",
	"reentry":"导弹升空时拖出尾烟，俯冲时弹头泛起热晕；落地后尘浪扩开，流星向四周散出，连成十二星座之一。",
	"quiet_sonar":"鱼雷穿过青紫光环，拖出双螺旋尾流。命中后水面泛起回声，克苏鲁幻影从水里探出，再随光弧下沉。",
	"love_peace":"引爆时，小爱心围着三行 LOVE、&、PEACE 字样散开，最后浮出一颗大爱心。"
}
const STOCK_TEXT := {
	"skin":"使用该单位的原版配色与外观。",
	"paint":"使用原版车身与武器配色。",
	"weapon_fx":"使用原版开火与命中特效。",
	"track":"行驶时留下原版车辙。",
	"top":"顶部不安装装饰。",
	"wing":"不安装悬浮挂件。",
	"tail":"不安装尾部挂件。"
}
const HERO_SKIN_TEXT := {
	"TANY":"紫黑赛博战衣配霓虹目镜与发光脊甲。双枪射出青白镭射，命中处迸出玫红色光刺。",
	"BORIS":"花纹泳裤、太阳镜和背装汽水瓶。橙色汽水枪打出一串气泡，击中时溅开泡沫。",
	"FV":"象牙白六轮装甲配蓝钢翼板。车尾片盒旁的两台投影机向外展臂，中央炮座随乘员换装，投影时在车侧投出同型炮塔。",
	"HARV":"赭红桁架跨过敞口矿斗，双面黄铜秤盘显示载货。压锤分段合钳，出膛后沿导轨后坐；车头机炮独立追瞄。",
	"E1":"冷蓝装具配银蓝肩甲与双片光学背鳍，肩下的晶坠会闪出青白星光，开火时枪口带一瞬淡青白辉光。",
	"E2":"铜钢铆接护肩下垂着炉芯链坠，背后双排气炉匣露出橙亮的散热栅，开火时枪口带一瞬暖琥珀余光。",
	"MTNK":"北辰专属。银白陶瓷侧装甲与星纹炮塔护肩采用精细材质，冰蓝回路随移动、选中及交战呼吸，开炮泛起青白辉光。车体与炮塔独立转向，保留阵营识别色。",
	"HTNK":"铁脊专属。深钢铆接侧装甲与熔炉炮塔护肩覆有磨损金属纹理，熔红回路随移动、选中及交战呼吸，开炮泛起橙红辉光。车体与炮塔独立转向，保留阵营识别色。"
}

static func effect_text(unit_id:String,slot:String,value:String) -> String:
	if value=="stock": return STOCK_TEXT.get(slot,"")
	if value=="night_shift":
		if unit_id=="NAREFN": return "银蓝钢板配金色反光条。坡道两侧的青白定位灯常亮，琥珀色引导灯随卸货进度逐盏熄灭。"
		return "银蓝车身配金色反光条。车顶灯排始终横向朝屏幕，两端青白定位灯常亮，四盏琥珀灯随载矿量从左到右亮起。"
	return EFFECT_TEXT.get(value,"")

const VICTORY_SKINS := {"winter":3}

# Keep item IDs in saves and loadouts. The workshop name determines which
# compatible variants a purchase or victory reward entitles the player to.
static var names_by_id:Dictionary = {}

static func display_name(value:String) -> String:
	if names_by_id.is_empty():
		for options in [Styles.SKINS,Styles.PAINT,Styles.TOP,Styles.WINGS,Styles.TAILS,Styles.TRACKS,WEAPON_NAMES]:
			names_by_id.merge(options)
		names_by_id.merge(SKIN_NAMES)
	return names_by_id.get(value,"")

static func owned(owned_ids:Dictionary,value:String) -> bool:
	if value=="stock":return true
	var label:=display_name(value)
	if label.is_empty():return false
	if owned_ids.get(value,false)==true:return true
	for id in owned_ids:
		if owned_ids[id]==true and display_name(id)==label:return true
	return false

static func victory_tier(value:String) -> int:
	var label:=display_name(value)
	for reward:String in VICTORY_SKINS:
		if display_name(reward)==label:return VICTORY_SKINS[reward]
	return 0

static func wins_required(value:String) -> int:
	var label:=display_name(value)
	var rewards:Dictionary=GameData.meta_config.get("cosmetic_win_rewards",{})
	for reward:String in rewards:
		if display_name(reward)==label:return int(rewards[reward])
	return 0

static func research_required(value:String) -> int:
	var label:=display_name(value)
	var rewards:Dictionary=GameData.meta_config.get("cosmetic_research_rewards",{})
	for reward:String in rewards:
		if display_name(reward)==label:return int(rewards[reward])
	return 0

static func available(id:String,slot:String,value:String) -> bool:
	if slot=="weapon_fx":return WEAPON_FX.has(id) and value in ["stock",WEAPON_FX[id]]
	var unit:Dictionary=GameData.unit_index.get(id,{})
	if slot=="skin":
		if EXCLUSIVE_SKINS.has(id) and value in ["stock",EXCLUSIVE_SKINS[id]]:return true
		return unit.get("ra2",false) and not Styles.is_ra3(unit) and Styles.SKINS.has(value)
	if unit.is_empty() or not Styles.is_ra3(unit):return false
	match slot:
		"paint":return Styles.PAINT.has(value)
		"top":return value in ["stock","crystal"] or (Styles.TOP.has(value) and Styles.EXCLUSIVE_MOUNTS.get(id)==value)
		"wing":return Styles.WINGS.has(value)
		"tail":return value=="stock" or (Styles.TAILS.has(value) and Styles.EXCLUSIVE_MOUNTS.get(id)==value)
		"track":return VehicleTracks.supports_tire_skin(id) and Styles.TRACKS.has(value)
	return false

static func win_reward_only(id:String,value:String) -> bool:
	return wins_required(value)>0 or Styles.is_ra3(GameData.unit_index.get(id,{}))

static func price(slot:String) -> int:
	return int(GameData.meta_config.get("cosmetic_prices",{}).get(slot,-1))

static func requirement(value:String) -> String:
	return "赢得一场凶残遭遇战" if victory_tier(value)==3 else "赢得一场困难或凶残遭遇战"
