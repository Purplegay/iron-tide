// Produce a row per retail trigger. Status is an explicit, separately maintained claim.
import fs from 'node:fs';
import {triggerBindings} from './retail_trigger_bindings.mjs';
import {parseIni} from '../../ra2pipe/lib/ini.mjs';
import {sha256} from '../../ra2pipe/lib/yr_source.mjs';
const [out,...files]=process.argv.slice(2);
if(files.length!==3)throw Error('OUT.tsv SOV01_MAP ALL02_MAP SOV07_MAP');
const identities=[['SOV01UMD','498b989a4b6f579dee0904a77f1fabf982c14786db21a46c41900fc8344ec72b'],['ALL02UMD','168ed42024991b6c2af4de0e5a667e9c2bf15767741efe99dac975721460b303'],['SOV07UMD','eacf89952cb6e8eacd762f97895a062e0b6bfa16c8f916b901c1e667def266d4']];
const coverage={
 'SOV01UMD:043e763c':['已接并专项验证','time_shift.gd::recharge_reminder','正式战场读零售80秒规则，充能中提醒一次；--recharge-reminder'],
 'ALL02UMD:094d821c':['已接并专项验证','hollywood_mission.gd::repair_depot_taunt','完工NADEPT存在触发尤里原声，GADEPT和施工不触发；--depot-taunt'],
 'ALL02UMD:096169cc':['已接并专项验证','hollywood_mission.gd::discover_dinosaur','原格进入或飞越，揭雾及招募/原声；--dinosaur'],
 'ALL02UMD:07f40cac':['部分接线','hollywood_mission.gd::plants_tick','停运分支1秒后尤里喊话；--retail-ai 验首次拆二号厂，复用一次性状态未逐项核对原重复机制'],
 'ALL02UMD:0618f5cc':['部分接线','hollywood_mission.gd::fortress_tick','实验室完工门槛、KE入场、原编组、CR移动和介绍；--fortress-chain，未验自然抵达及原卡动作细节'],
 'ALL02UMD:07ac738c':['已接并专项验证','hollywood_mission.gd::fortress_tick','20秒后独立CR报点、到达语音且不重复；--fortress-chain'],
 'SOV01UMD:0b554afc':['部分接线','time_shift.gd::tick','入口69轮番及随机5至15秒，--dino-contact 验进视野及遭受攻击；原目标脚本后半未接'],
 'SOV01UMD:0b557e6c':['部分接线','time_shift.gd::tick','入口70轮番及随机5至15秒；--dino-contact 验接敌，原启停由阶段适配'],
 'SOV01UMD:0952f87c':['部分接线','time_shift.gd::change_era/tick','120秒充能与恐龙调度已有，现版从过场后推进，未复刻启用等待、全套命令和开关'],
 'SOV01UMD:0bde333c':['部分接线','time_shift.gd::tick','120秒届满停止增援并安排穿越，原后续文字与开关仍近似'],
 'SOV01UMD:0bde064c':['部分接线','time_shift.gd::tick','充能结束播放原声并开始穿越；未恢复原 1 秒和鲍里斯分流开关'],
 'SOV07UMD:093c666c':['部分接线','head_games.gd::rally_volunteers','存在的5名原图单位进入视野后接管、揭示报点与原声；--volunteers'],
 'SOV07UMD:093bb0fc':['部分接线','head_games.gd::rally_volunteers','解锁两型生产但保留工厂与雷达前置；--volunteers 验扣费出厂，队伍尾动作未完整复刻'],
 'SOV07UMD:093b91cc':['部分接线','head_games.gd::media_events','志愿军后5秒武器/人物音效请求，未独立实听'],
 'SOV07UMD:093caf3c':['部分接线','head_games.gd::media_events','志愿军后10秒卡车音效请求，以累计延时适配启用链'],
 'SOV07UMD:0b5a5b5c':['部分接线','head_games.gd::objectives','盟军侧信标消失后转属、阻断敌超武；主线，局部标志与禁用集仍以状态适配'],
 'SOV07UMD:0b5a6b7c':['部分接线','head_games.gd::objectives','苏军侧信标消失后转属、阻断敌超武；主线，局部标志与禁用集仍以状态适配'],
 'SOV01UMD:06b2a4dc':['部分接线','time_shift.gd::change_era','最终时代巡逻、警戒和修电站单位有对应，核电站专项复验；原动作启停仍不等价'],
 'SOV01UMD:0442182c':['部分接线','time_shift_events.gd::mixed_attack','接管后混编计时和原队形已有，非完整行动38房号解释；先前 --island-teams'],
 'SOV01UMD:092fb88c':['部分接线','time_shift_events.gd::mixed_attack','独立延时副队已有，攻击选择仍有适配；先前 --island-teams'],
 'SOV01UMD:04421a8c':['部分接线','time_shift_events.gd::mixed_attack','首支混合队失去敌方存活成员后重计时；先前 --island-teams，事件48未通用解释'],
 'ALL02UMD:094d906c':['已接并专项验证','hollywood_mission.gd::new_mission_notice','15秒后广播、文字并接120秒后继；--grinder-layout'],
 'ALL02UMD:04627bcc':['已接并专项验证','hollywood_mission.gd::new_mission_notice','后继120秒文字提醒只发一次；--grinder-layout'],
 'ALL02UMD:0439850c':['部分接线','hollywood_mission.gd::plants_tick','原航点放箱、停居民路线、启用喊话；完整禁用链未迁移'],
 'ALL02UMD:0439edbc':['部分接线','hollywood_mission.gd::plants_tick','原航点放箱、停居民路线、启用喊话；完整禁用链未迁移'],
 'ALL02UMD:0439eaac':['部分接线','hollywood_mission.gd::plants_tick','原航点放箱、停居民路线、启用喊话；原标志4以状态适配'],
 'ALL02UMD:0439e79c':['部分接线','hollywood_mission.gd::plants_tick','原航点放箱、停居民路线、启用喊话；原标志5以状态适配'],
 'ALL02UMD:090a9f3c':['部分接线','hollywood_mission.gd::discover_facilities','可见性、揭雾闪烁雷达及原声，标志以访问状态适配；主线'],
 'ALL02UMD:0915431c':['部分接线','hollywood_mission.gd::discover_facilities','可见性、揭雾闪烁雷达及原声，标志以访问状态适配；主线'],
 'SOV07UMD:0aa45a2c':['部分接线','head_games.gd::grinder_lost','西南资金箱、居民路线释放；未逐条复刻原房号及解散动作；--grinder-script'],
 'SOV07UMD:0aa466cc':['部分接线','head_games.gd::grinder_lost','东北资金箱、居民路线释放；未逐条复刻原房号及解散动作；--grinder-script'],
 'SOV01UMD:08e497ac':['已接并专项验证','time_shift.gd::finish_dominator','原目标完成文字，一秒后、结算前；time_shift 主线'],
 'SOV01UMD:06b602bc':['已接并专项验证','time_shift.gd::finish_loss','15秒失败结算；--loss、--power-loss'],
 'SOV01UMD:06b6156c':['部分接线','time_shift.gd::begin_loss','电厂数门槛近似，3秒后原声并开启失败计时；--power-loss'],
 'SOV01UMD:095180bc':['部分接线','time_shift.gd::tick','开场时光机引用失效触发，未逐项解释禁用后继及占领事件'],
 'SOV01UMD:079d7e1c':['部分接线','time_shift.gd::tick','接管后时光机引用失效触发，未逐项解释禁用链'],
 'SOV01UMD:0bb91c2c':['部分接线','time_shift.gd::tick','侏罗纪时光机毁坏后原声及15秒负；--loss，原禁用动作以状态保护适配'],
 'SOV01UMD:097154cc':['部分接线','time_shift.gd::tick','现有玩家全灭检查启用15秒收尾；房号与阶段边界近似，未专项验证'],
 'ALL02UMD:05d9ee6c':['已接并专项验证','hollywood_mission.gd::clint_report','15秒后卡维利 A02_P03E；--actor-report-sale'],
 'ALL02UMD:09164acc':['部分接线','hollywood_mission.gd::discover','原声与启用卡维利计时，受害队与后续开关未逐项解释'],
 'ALL02UMD:0916204c':['部分接线','hollywood_mission.gd::discover','位置接近后转属，原局部变量、镜头及随行队未齐'],
 'ALL02UMD:07a3955c':['部分接线','hollywood_mission.gd::fire_sale','副房现场出售，及后续计时；--actor-report-sale，原房经济有适配'],
 'ALL02UMD:0b20458c':['部分接线','hollywood_mission.gd::withdrawals_tick','五秒后重发并实际命中；--actor-report-sale，以攻击移动适配 Hunt'],
 'ALL02UMD:0cebd51c':['部分接线','hollywood_mission.gd::withdrawals_tick','按实际本房被毁数量和关键设施启动主房出售，未专项验证'],
 'ALL02UMD:0938862c':['部分接线','hollywood_mission.gd::withdrawals_tick','主房6秒后发起攻击移动；原 Hunt 有适配，未专项验证'],
 'ALL02UMD:0c42981c':['部分接线','hollywood_mission.gd::plants_tick','四个回收厂停运后变更目标，运行以剩余数量近似局部变量链'],
 'ALL02UMD:0cddc84c':['部分接线','hollywood_mission.gd::tick','停运后原声及清剿目标，居民队与停止声音未逐项解释'],
 'ALL02UMD:088f344c':['缺原图专用链','hollywood_mission.gd::finish_timeline','现有获救居民随结尾欢呼，原独立10秒及房号12未确认启用源'],
 'SOV07UMD:06a1603c':['已接并专项验证','head_games.gd::field_events','原图彩蛋格地面进入，载员不触发；--backdoor-script'],
 'SOV07UMD:0cbdea2c':['部分接线','head_games.gd::field_events','后路格触发雷达与语音，不开雾；原发现动作以地面格进入适配；--backdoor-script'],
 'SOV07UMD:0921d64c':['部分接线','building.gd::_die','西墓室映射 CATRAN02，直接熄灯代替局部标志20；--orders'],
 'SOV07UMD:09220ccc':['部分接线','building.gd::_die','东墓室映射 CATRAN01，直接熄灯代替局部标志21；未专项验证东侧'],
 'SOV07UMD:0922057c':['部分接线','building.gd::_die','西灯隐藏而非销毁原灯实体；--orders'],
 'SOV07UMD:07df0f3c':['部分接线','building.gd::_die','东灯隐藏而非销毁原灯实体，未专项验证东侧'],
 'SOV07UMD:05bc965c':['部分接线','head_games.gd::castle_attacked','正伤害触发警报及预设守军；原编队和工事目标未逐项验证'],
 'SOV01UMD:0c47f71c':['部分接线','time_shift.gd::finish_dominator','目标摧毁、欢呼与镜头有对应，已补08E497AC，禁用链仍为状态适配'],
 'SOV01UMD:06b600ec':['已接并专项验证','time_shift.gd::finish_dominator','5秒后胜利'],
 'ALL02UMD:0cddecbc':['部分接线','hollywood_mission.gd::tick','以当前任务目标判定进入收尾，非完整局部变量解释'],
 'ALL02UMD:0cddc53c':['部分接线','hollywood_mission.gd::finish_timeline','3秒欢呼，平民房另有原图触发'],
 'ALL02UMD:0cddc22c':['已接并专项验证','hollywood_mission.gd::finish_timeline','并行10秒结算'],
 'ALL02UMD:09635f3c':['部分接线','hollywood_mission.gd::withdrawals_tick','副房立即追击与延迟重发；启用条件仍有适配'],
 'SOV07UMD:0e2ab85c':['部分接线','head_games.gd::objectives','摧毁城堡后三秒拆信标与转属'],
 'SOV07UMD:0cd9e15c':['部分接线','head_games.gd::objectives','摧毁城堡后三秒拆信标与转属'],
};
// Batch 05: event-level results; extracted data is not itself implementation proof.
const fleet=JSON.parse(fs.readFileSync(new URL('../data/maps/time_shift_fleet.json',import.meta.url)));
const markSea=(id,state,entry,note)=>{
 const key='SOV01UMD:'+id.toLowerCase();
 if(coverage[key])throw Error('Duplicate coverage: '+key);
 coverage[key]=[state,entry,note];
};
const partial='部分接线', verified='已接并专项验证';
for(const ship of fleet.fleet){
 const inside=fleet.groups.some(g=>g.ships.some(s=>s.slot===ship.slot));
 markSea(ship.detect,partial,'time_shift_events.gd::fleet_reinforcements',`原队${ship.id}/标签${ship.tag}/站位${ship.slot}；${ship.flag===null?'二号无畏舰直接启一秒补援':inside?'原变量'+ship.flag+'以对应存活槽代用':'原变量'+ship.flag+'未写入；不作为补援条件'}；--fleet-reinforcements 验开局身份及分组，未逐个验转属或原旗标`);
}
for(const row of fleet.opening){
 markSea(row.id,partial,'time_shift.gd::setup',`零售等待${row.delay}秒，动作7队伍 ${row.teams.join('/')}；现开局同时装配，未照原镜头逐组启用`);
}
for(const group of fleet.groups){
 markSea(group.id,partial,'time_shift_events.gd::fleet_reinforcements',`零售队 ${group.ships.map(s=>s.id).join('/')} 正式入场并接到航点命令；--fleet-reinforcements；条件以存活槽代原旗标，实际抵达及反复全灭未验`);
 markSea(group.notice,verified,'time_shift_events.gd::fleet_notices',`等待${group.notice_delay}秒，固定原航点${group.flash.join('/')}，${group.cue?'到达录音':'仅雷达，无EVA'}；--fleet-reinforcements 与 --cold-fleet-disarmed`);
}
for(const [id,entry,note] of [
 ['0900AB1C','fleet_reinforcements','二号无畏舰6秒后可再侦测，未区分重开前已阵亡的原事件处理；时长来自表'],
 ['0B752F3C','phase 0 / cleared','按标签全清后停止补舰并进登陆；原12队创建、房号关系及分期启用非等价'],
 ['0BBB5C6C','fleet_disarm','同时停掉13个侦测关系，保留已经排队的雷达与语音；未仿真每条旗标'],
 ['0B92C6AC','land','原5秒后转镜头及播EVA，现直接进入登陆和雷达短片'],
 ['0B8A28BC','land','原30秒转镜头再启片段，现立即转岸边'],
 ['094DC05C','land / scenario_film','原镜头链再等1秒开索菲亚短片，现登陆时播S01_P01E'],
 ['0833254C','scenario_film','原另等18秒进语音，现从片尾回调排三句'],
 ['0BAFDF3C','landing_transport','08816EFC：四犀牛，23转55、卸载后退离路线/原局部旗标未齐；现四艇同派'],
 ['0BAF8ABC','landing_transport','08DF843C：十二动员兵，23转56；现四艇同派，未保留逐组7秒等待及退离'],
 ['0BAFCC3C','landing_transport','0B5CAEFC：四防空履带车，23转57；现四艇同派，未保留5秒等待和原脚本动作'],
 ['0BAF845C','landing_transport','0B244DEC：鲍里斯、磁暴兵、军犬、工程师，23转58；现四艇同派，未保留5秒等待和退离'],
 ['0959CAFC','landing_backup_tick','犀牛载艇沉没进入替补支路；--landing-backup；不解释原房号和旗标'],
 ['0959C92C','landing_backup_tick','动员兵载艇沉没进入替补支路；--landing-backup；不解释原房号和旗标'],
 ['082C44AC','landing_backup_tick','犀牛补艇等待9秒；--landing-backup；未逐步复刻0999948C脚本'],
 ['082C467C','landing_backup_tick','动员兵补艇等待3秒；--landing-backup；未逐步复刻0999AEFC脚本'],
 ['082C3CEC','landing_backup_tick','首批陆上犀牛全灭并发两路后援；--landing-group-loss；判定用运行时乘员引用'],
 ['0B603E5C','landing_backup_tick','替补队卸载后播录音、文字和雷达；旗标43、分派小队及原报点未逐动作等价'],
 ['0B60744C','landing_backup_tick','替补队卸载后播录音、文字和雷达；旗标44、分派小队及原报点未逐动作等价'],
])markSea(id,partial,`time_shift.gd / time_shift_events.gd::${entry}`,note);
for(const row of [...Object.values(fleet.grid.plants),...fleet.grid.loss])markSea(row.id,partial,'time_shift_events.gd::power_losses','实际任务电厂损失按表推动40/41/42；同扫描多座逐一结算，非原引擎触发遍历复刻');
for(const row of Object.values(fleet.grid.attackWarnings))markSea(row.id,partial,'building.gd::receive_hit → time_shift_events.gd::grid_attack_warning','实际正伤害、供电期和目标门槛；原房攻击事件以玩家来源适配');
for(const row of [...Object.values(fleet.grid.tech),fleet.grid.warning,fleet.grid.techDisable])markSea(row.id,partial,'time_shift_events.gd::tech_power_warning','逐厂ID和停用表、三秒告警；以现版三座及合并战斗房适配原 Arabs 条件');
for(const [key,row] of Object.entries(fleet.grid.full))if(key!=='effect'&&key!=='animation')markSea(row.id,partial,'time_shift.gd::finish_power_grid','首次足额、原延迟播报/镜头/完成；625沿用现版，原分镜动作与链并非全量');
for(const spec of Object.values(fleet.transportReturns)){
 if(spec.flag!==spec.event_flag)continue;
 markSea(spec.id,partial,'time_shift_events.gd::advance_raid_return','载员卸完交接空艇；复用同一船体执行零售返航航点，未自然逐艇完成');
 markSea(spec.reset,partial,'time_shift_events.gd::advance_raid_return','正式读取原图一秒清除；用每艇状态近似原本地图变量和重新启用');
}
for(const [name,spec] of Object.entries(fleet.engineer)){
 if(name==='sale')continue; // Sale action itself is not newly supported.
 markSea(spec.id,partial,'time_shift_events.gd::engineer_reinforcements / engineer_notices',`读表计时、载员、文字或雷达；供电阶段及飞机调度仍为适配`);
}
markSea('0DD0203C',partial,'time_shift_events.gd::engineer_reinforcements','用存活工程师和空投载员判定全灭，再启补机；--engineer-drop，尚非原标签精确等价');
for(const step of fleet.power){
 markSea(step.id,partial,'time_shift_events.gd::power_contest',`原图延时${step.delay}秒、难度及后继顺序由表驱动；--power-raid-chain。沿用供电阶段时钟、原有船队适配；其余原动作未全接`);
 if(step.ping)markSea(step.ping.id,partial,'time_shift_events.gd::power_contest',`突击支路派出后${step.ping.delay}秒标原航点${step.ping.slot}；--power-raid-chain；沿用项目雷达闪烁样式`);
}
markSea(fleet.reminder.id,partial,'time_shift.gd::scenario_film/tick','原100秒、一次提醒、清岸防取消；--naval-reminder。启用点以玩家接管代原开场分镜');
markSea(fleet.objective.id,verified,'time_shift.gd::tick','清岸防停侦测后1秒实际发中文报文和原声；--naval-objective / --cold-naval-objective');
const s07=JSON.parse(fs.readFileSync(new URL('../data/maps/head_games_drivers.json',import.meta.url)));
function markS07(id,entry,note){const key='SOV07UMD:'+id.toLowerCase();if(coverage[key])throw Error('Duplicate '+key);coverage[key]=['部分接线',entry,note];}
for(const row of s07.routes){
 markS07(row.id,'head_games_orders.gd::tick','读取随机周期及正式启停，原出发点与回收路线；已有首轮60秒适配不改');
 markS07(row.sourceDeath.id,'head_games_orders.gd::tick','源房消失后执行零售停用清单，包含N房同时关两路；源屋引用代替对象标签事件');
}
markS07(s07.start.id,'head_games_orders.gd::tick','建造场后原3秒启用9路；已有首波路线时钟不重置');
for(const row of s07.attack)markS07(row.id,'head_games.gd::attackers','从正式任务读部署关系、首攻延时及难度；沿用现有落点、命令与势力解放适配');
for(const row of Object.values(s07.yards))markS07(row.id,'head_games.gd::retail_yard_disabled','按原禁用列表停止该房超武剧情分支；按实际建造场失去状态适配');
for(const row of Object.values(s07.combo))markS07(row.id,'head_games_combine.gd','第11批：启动、轮次、搭乘、伤亡替补、循环与警报按原关系和时长；仍以项目单位状态适配原房与旗标');
for(const row of s07.finish)markS07(row.id,'head_games.gd::objectives','第11批：原城堡毁坏、欢呼延时、循环及胜利延时，沿用目前的转属适配');
for(const row of s07.briefing.slice(2))markS07(row.id,'head_games.gd::briefing','第11批：原盟军/苏军/交还操控的后继与间隔；导览由本项目雷达简报开始');
for(const row of Object.values(s07.superRows))markS07(row.id,'head_games.gd::superweapon_built / media_events','第12批：完成科技建筑、难度、未解放分支或后继延时；正式生成超武或电台，沿用任务落点及合并房适配');
for(const row of Object.values(s07.opening))markS07(row.id,'head_games.gd::setup / head_games_orders.gd::prepare','第12批：零售难度、队员、航点或驻军目标；沿用开场装配与就近驻军');
for(const row of Object.values(s07.landing))markS07(row.id,'head_games.gd::arrive / attackers','第12批：两批队员、原图目标航点及三秒后继，保留可通行入场适配');
for(const row of Object.values(fleet.media))markSea(row.id,partial,'time_shift.gd::scenario_film / time_shift_events.gd::media_tick','第12批：原电台、延时、镜头、标记或设施后继；片尾、走出运输艇和可见性代零售部分上游事件');
const h13=JSON.parse(fs.readFileSync(new URL('../data/maps/hollywood_drivers.json',import.meta.url)));
function markH13(id,entry,note){const key='ALL02UMD:'+id.toLowerCase();if(coverage[key])throw Error('Duplicate '+key);coverage[key]=['部分接线',entry,'第13批：'+note];}
for(const row of Object.values(h13.waves))markH13(row.id,'hollywood_mission.gd::difficulty_attacks','原图难度、延时、下一波、队员、出生与移动航点；撤退和择敌沿用适配');
for(const row of [...Object.values(h13.intro),h13.gate])markH13(row.id,'hollywood_mission.gd::difficulty_attacks','从发现克林特及困难车厂条件启用原图波次；未替换其它同行动作');
for(const row of Object.values(h13.residents)){
 markH13(row.id,'hollywood_mission.gd::retail_residents','活跃回收厂下按原住民类型与出发航点补位，采用可走格投影');
 markH13(row.change,'hollywood_queue.gd::advance','到达排队点、随机延迟后准许回收；复用原居民，未重演零售换队消失动作');
}
function markH14(id,entry,note){const key='ALL02UMD:'+id.toLowerCase();if(coverage[key])throw Error('Duplicate '+key);coverage[key]=['部分接线',entry,'第14批：'+note];}
for(const row of Object.values(h13.sources))markH14(row.id,'hollywood_mission.gd::bind_retail_sources / retail_residents','原标签按地图类型和地基绑定，源楼被毁停止对应后续生成');
for(const row of Object.values(h13.staged))markH14(row.id,'hollywood_mission.gd::staged_residents','三厂按原30秒、原角色和后继补入初期居民；上游以发现克林特适配，保留通用排队');
for(const row of h13.bridges){
 markH14(row.id,'hollywood_bridge_fixers.gd::tick','原CellTag断面损毁启动维修作业');
 markH14(row.fixer,'hollywood_bridge_fixers.gd::tick','60秒后按原落点、人数和小屋派出工程师');
 markH14(row.fixed,'hollywood_bridge_fixers.gd::tick','断面恢复后撤销该作业并允许重新损毁计时');
}
for(const row of Object.values(h13.hints))markH14(row.id,'hollywood_mission.gd::retail_goal_hints','雷达上线/失效启停、原120秒文字及四个航点；范围和可见性沿用项目机制');
function mark15(m,id,entry,note){const key=m+':'+id.toLowerCase();if(coverage[key])throw Error('Duplicate '+key);coverage[key]=['部分接线',entry,'第15批：'+note];}
for(const row of Object.values(fleet.ambience))mark15('SOV01UMD',row.id,'time_shift_events.gd::ambience','原图音源和时代、航点进入正式环境音；保留最近点与8秒采样');
for(const row of Object.values(h13.ambience))if(row.id!=='0463917C')mark15('ALL02UMD',row.id,'hollywood_retail_sequences.gd::ambience','原城市/鸟/海岸音源和位置，最近点采样，非原引擎并发调度');
for(const row of Object.values(h13.special))mark15('ALL02UMD',row.id,'hollywood_retail_sequences.gd::special_waves','原阶段计时、队员、移动或旧队释放；两种合队按现场旧队存活适配');
for(const row of Object.values(h13.cleanup))mark15('ALL02UMD',row.id,'hollywood_retail_sequences.gd::cleanup','清场中的原段落、角色类型、旧队退场；复用获救者，不复制原复招/消失');
for(const row of Object.values(h13.lifecycle))if(row.id!=='0921C8DC')mark15('ALL02UMD',row.id,'hollywood_retail_sequences.gd::latches / hollywood_mission.gd::tick','设施、房组退出、目标或失败时钟；现有房归属与失去/完成状态适配');
for(const id of ['0930F29C','093093FC','099AEA1C','099AFF3C','0930C5CC','0932705C','091B6F3C','088509DC','04384E4C','043842DC'])mark15('ALL02UMD',id,'hollywood_mission.gd::intro / briefing_point','保留现有影片及锁控时序，从表读取对应镜头、提示或后继关系');
function mark16(m,id,entry,note){const key=m+':'+id.toLowerCase();if(coverage[key])throw Error('Duplicate '+key);coverage[key]=['部分接线',entry,'第16批：'+note];}
for(const row of Object.values(fleet.late)){
 const id=row.id;
 const entry=['094A4E1C','0DECD98C'].includes(id)?'acquire_machine':row.hit.length||row.target||id==='07A5F24C'?'bridge':row.buildings.length||row.teams.length?'return_city':'tick / apply';
 mark16('SOV01UMD',id,'time_shift_late.gd::'+entry,'零售目标、队员/出生、标点、播报、启用或延时驱动；事件来源与剩余动作详见交接');
}
for(const id of ['0916B4CC','0ABA8C5C','0ABAE7BC','08E32CFC','065C3EDC','06C3CCCC','093C2ADC','0B0F83EC','04EF835C','092C9D5C','0B8E13AC','096947BC','0967DE9C'])mark16('ALL02UMD',id,'hollywood_mission.gd::setup / intro / discover / start_patrols','原编组、路线、难度、受袭启用或标点；原方案与现行玩家入场/就近驻军适配');
function mark17(m,id,entry,note){const key=m+':'+id.toLowerCase();if(coverage[key])throw Error('Duplicate '+key);coverage[key]=['部分接线',entry,'第17批：'+note];}
for(const row of Object.values(fleet.staging))mark17('SOV01UMD',row.id,'time_shift_staging.gd / time_shift.gd','零售镜头、航点、延时、启停、援军或提示正式进场；实际覆盖依本批交接，不等价全部同行动作');
for(const row of Object.values(h13.extra))mark17('ALL02UMD',row.id,'hollywood_mission.gd / hollywood_retail_sequences.gd','原机场及镜头、回收厂受袭、披露区与开场动作进入正式阶段；不改媒体文件');
for(const row of Object.values(s07.grinder))mark17('SOV07UMD',row.id,'head_games.gd::grinder_apply / grinder_retail_tick','原发现/受袭/毁厂反击、队伍与延时；现有地图出生和势力适配');
for(const id of ['0947BC0C','092D8F3C','05FD863C'])mark17('SOV07UMD',id,'head_games.gd::start_radio / check_player_loss','开场雷达通讯/揭示及全灭判定依零售启用；沿用视频接点与实战存活检测');
function mark18(m,id,entry,note){const key=m+':'+id.toLowerCase();if(coverage[key])throw Error('Duplicate '+key);coverage[key]=['部分接线',entry,'第18批：'+note];}
for(const row of Object.values(fleet.batch18))mark18('SOV01UMD',row.id,'time_shift_retail_cleanup.gd / time_shift_events.gd','原启用、延时、设施归还或角色与运输命令；房号/标签及部分同行动作沿用适配');
for(const id of ['0965013C','0965263C','0965230C'])mark18('SOV07UMD',id,'head_games.gd::retail_hostility_cells','原格进入各唤起一房生产评估；仍沿用合并战斗侧，不重写外交');
coverage['SOV01UMD:'+fleet.powerAlarm.id.toLowerCase()]=['部分接线','time_shift_events.gd::dominator_power_alarm','第19批：防守阶段四厂映射原 Arabs 满电；通过原停用状态门控，播放警笛、中文字和原 EVA'];
function mark19(id,entry,note){const key='ALL02UMD:'+id.toLowerCase();if(coverage[key])throw Error('Duplicate '+key);coverage[key]=['部分接线',entry,'第19批：'+note];}
for(const row of Object.values(h13.voices)){
 mark19(row.id,'battle.gd::_apply_selection / hollywood_retail_sequences.gd::resident_click','按原 TeamType 标签播放零售选中语音，不选中或转属 NPC');
 mark19(row.next,'hollywood_retail_sequences.gd::voice_tick','十规则秒后重新启用对应语音，同原触发器共享冷却');
}
mark19('0463917C','hollywood_retail_sequences.gd::ambience','三处原图坐标与十二个原声样本；沿用当前最近点采样而非原并发播放');
for(const id of ['0926703C','0464860C','07A40B2C','09D2968C'])mark19(id,'hollywood_retail_sequences.gd::westwood_tick / resident_click','对应侦察卫星、原备援格、点击克林特或发现克林特；启停合流至原揭示及英雄归队，未迁完整受害队');
function mark20(m,id,entry,note){const key=m+':'+id.toLowerCase();if(coverage[key])throw Error('Duplicate '+key);coverage[key]=['部分接线',entry,'第20批：'+note];}
for(const row of Object.values(fleet.encounter))mark20('SOV01UMD',row.id,'time_shift_staging.gd::assign_encounter','零售 3 秒和原队类型，复用实战单位并给原路点命令；未补齐整队后续脚本');
mark20('SOV01UMD',fleet.boatLoss.id,'time_shift_events.gd::boat_loss','接管后运输艇、建造厂、船坞三项皆无时进入原 15 秒失败，已冷读');
for(const id of Object.keys(h13.prisoners))mark20('ALL02UMD',id,'unit.gd::receive_hit / hollywood_retail_sequences.gd::prisoners_tick','原标签守卫受伤后唤醒，间隔 1 秒按原六人编组撤跑；逃跑路径为适配');
const batch21={SOV01UMD:{'096879AC':'旧时代 45 秒清指定房单位，未迁原全房结构清除','097651DC':'在世鲍里斯取消替补','0CAAF7DC':'第二次穿越换场前归还旧时光机','07F2978C':'原巨型乌贼二号死亡旗标，余美军中立化适配','0937687C':'七处原路点重盖局部黑幕，未复刻原矩形','078C97EC':'桥损毁接原一秒后继；本节点无原对象','079BB93C':'仅原桥附属类型转回中立','06A67A6C':'已卸空 Grand 船仅在 Gas 卸载后按原路返航','0C122E5C':'一秒后清 Grand 旗标'},ALL02UMD:{'08D5E88C':'阿拉伯房全灭后启用无目标后继','08E7FF3C':'苏军房全灭后启用无目标后继','0EB68F3C':'普通/困难售出原坐标防空炮','0963AA4C':'原 3 步兵 1 盖特齐员后接局部旗标及攻击命令','088F344C':'独立中立欢呼时钟；与结算同一时点'}};
for(const [mission,rows] of Object.entries(batch21))for(const [id,note] of Object.entries(rows)){
 const key=mission+':'+id.toLowerCase();
 if(coverage[key]&&id!=='088F344C')throw Error('Duplicate '+key);
 coverage[key]=['部分接线',mission==='SOV01UMD'?'time_shift_retail_cleanup.gd / time_shift_events.gd':'hollywood_retail_sequences.gd / hollywood_bases.gd','第21批：'+note];
}
for(const id of ['087D15EC','082B950C','082B933C'])coverage['SOV01UMD:'+id.toLowerCase()]=['部分接线','time_shift.gd::landing_backup_tick / time_shift_retail_cleanup.gd::landing_team','第22批：同批实船卸空后按零售编制绑定现存队员，空闲首批守卫、补援雷达标点；保留玩家命令，未复刻完整原旗标与闪烁'];
coverage['SOV01UMD:09601d2c']=['部分接线','time_shift.gd::advance_crossing / time_shift_retail_cleanup.gd::phase_apply','第23批：0BDE287C 启用，079D7E1C 链接至 09519F4C 所附 CATIME01；一秒后退役旧机归原房15，保留新机可控'];
coverage['ALL02UMD:10a9144c']=['部分接线','hollywood_retail_sequences.gd::closure_tick','第24批：经 0EB68F3C 的链接继承 10A95F4C，简单难度一秒出售原 NAFLAK，退款归玩家，未改变普通分支'];
const noTransfer=new Map(Object.entries({
 'SOV01UMD:0441baac':['0975f31c','0c4a628c'],
 'ALL02UMD:0930c39c':['0931d05c',''],
 'ALL02UMD:0acd381c':['0acd0f4c','08d5e88c'],
 'ALL02UMD:08e7fb5c':['08e7f47c','08e7ff3c'],
 'ALL02UMD:07f39f3c':['07f39a4c',''],
 'ALL02UMD:07f31bac':['07f3162c',''],
 'ALL02UMD:07f3122c':['07f32f4c',''],
}));
coverage['SOV01UMD:0c46ab3c']=['已接并专项验证','time_shift.gd / time_shift_retail_cleanup.gd','第26批：0C46AA5C 链接六座原电厂；只恢复存活原厂，返城按 0BDCDD0C 启用后一秒转给 Americans，独立进程冷读前后验证'];
const output=[['关卡','触发ID','零售Triggers','Events','Actions','Tags','CellTags','状态','运行入口','验证或限制']];
for(let i=0;i<files.length;i++){
 const raw=fs.readFileSync(files[i]); const [mission,hash]=identities[i]; if(sha256(raw)!==hash)throw Error('Wrong map '+files[i]);
 const map=parseIni(raw.toString('latin1'));const sec=k=>map.get(k)?.keys??new Map();
 for(const [id,definition] of sec('triggers')){
  const ev=sec('events').get(id), act=sec('actions').get(id); if(!ev||!act)throw Error(mission+':'+id);
  const tags=[...sec('tags')].filter(([,v])=>v.split(',').at(-1).toLowerCase()===id).map(([k])=>k);
  const cells=[...sec('celltags')].filter(([,v])=>tags.includes(v.toLowerCase())).map(([n])=>n);
  let status=coverage[mission+':'+id]??['已提取，待逐条核验','','不据此判断未接'];
  const expected=noTransfer.get(mission+':'+id);
  if(expected){
   const binding=triggerBindings(map,id);
   const incoming=[...sec('actions')].filter(([,v])=>{
    const fields=v.toLowerCase().split(',').slice(1);
    return fields.some((op,i)=>i%8===0&&['22','53'].includes(op)&&fields[i+2]===id);
   }).map(([key])=>key);
   if(binding.tags.join()!==expected[0]||binding.uses.length||incoming.join()!==expected[1]||!/^1,14,/.test(act))throw Error('Recheck targetless transfer '+mission+'/'+id);
   status=['原图无绑定对象，已结项','零售 MAP 标签/链接/全段引用校验','第26批：动作14；标签 '+binding.tags[0].toUpperCase()+' 未被对象、地格、小队或动作引用；启用/强制来源 '+(incoming.join('/').toUpperCase()||'无')+'；无归属变化'];
  }
  output.push([mission,id.toUpperCase(),definition,ev,act,tags.join(','),cells.join(','),...status]);
 }
}
if(output.length!==682)throw Error('Unexpected number of triggers');
const exportedKeys=new Set(output.slice(1).map(([mission,id])=>mission+':'+id.toLowerCase()));
for(const key of Object.keys(coverage))if(!exportedKeys.has(key))throw Error('No retail trigger for '+key);
fs.writeFileSync(out,output.map(r=>r.join('\t')).join('\n')+'\n');
