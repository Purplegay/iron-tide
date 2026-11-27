# 美国首关电厂、岸炮、控制器与原图舰队

Iron Tide 0.32，正式入口为战役菜单的《Time Lapse》。计数按 ALL01UMD 原图唯一 ID。

| 正式驱动表 | 本批新增 | 累计 | 剩余 |
|---|---:|---:|---:|
| [任务触发器](ALL01UMD_SCRIPT_RECHECK.tsv) | 24 | 144/334 | 190 |
| [地图全局 AI](ALL01UMD_GLOBAL_AI_RECHECK.tsv) | 0 | 4/165 | 161 |

## 战场变化

| 条数 | 原图记录 | 正式执行与验收 |
|---:|---|---|
| 1 | Sell_Psychic | 换场交接启用。标签 089ED98C 的关联链指向原控制器实例 1028463。动作 60 走建筑出售，53 启用已有 Build_Dom。一游戏秒后 Confederation 开始施工。旧档已挂起的 Build_Dom 可直接续走。 |
| 6 | Change_House_PP1/2、Start_PP3–6_Check(s) | 开局一游戏秒后按原字段交接房号并启用八厂各自的占领和损毁监听。第六厂的记录还启用第七、第八厂监听。 |
| 9 | PP1–8_PlayerAttack、PowerAttacked | 实际受到美国玩家房伤害时逐厂显示 MISSION:Attack3 警告，并经 PowerAttacked 播放 xa1ev05。其它房号伤害通过反例核对。 |
| 8 | Cannon1–4_Gone、Rebuild_Cannon1–4 | 各原始岸炮受毁后锁存本炮变量 50–53。穿越交接时只有对应变量置位才从原航点重建，保留完好岸炮。四炮全毁和部分损失分别复验。 |

地图另有 16 个按任务直接派遣的舰队 TeamType。四组出场来源为 Fix_Buildings、Create_Stuff、Create_Stuff2、Kill_Sounds3。原有出场阶段现读取原动作的航点、TaskForce、房号和 ScriptType，涵盖七艘无畏舰、六艘海蝎、两艘邮轮及一艘拖船。海蝎按各自路线巡逻，实测航行。DX 无畏舰发射导弹命中核电站。舰队是以前已有的关卡行为，本批将其改成从原图数据执行。巡逻和炮击专项覆盖代表队伍，未逐舰跑完所有航点。无畏舰对地航点沿用每步一次发射的适配，舰队出场时点沿用既有换场和通讯交接。Sell_Psychic 的上游 Start_Sounds2 以及岸炮重建的上游 Clean_Map 仍由换场交接代理。

## 全局 AI 原图条件

165 个开关全部启用。唯一行动 3 的目标为房号 7 Confederation。按本房条件筛查，116 条阵营或国家不符，31 条科技超出 2 级，余下 18 条在逐 ID 表列出主队编成和条件对象。场内本房开局只有 NANRCT 与 YAPPET，建造计划只有 YAPPPT，场外为 YACNST。地图脚本派出的步兵或舰艇有各自房号、队伍与命令。此次未观测到新增的全局自然选队。原先 4 条的正向生产仍有夹具设施前置。导出器使用原图索引与安装版 AIMD 重新生成，实测既有 AI 运行数据与导出副本逐字节相同。

## 验收与复跑

Godot 4.7.2 在隔离 APPDATA 运行 `--headless --path . res://tests/allied_first_playable.tscn --`，随后传下列参数。证据在 `.validation/allied01-retail24/`。

| 场景 | 参数或证据 |
|---|---|
| 逐 ID、电厂受击正反例、四炮损失、换场和舰队 | `--new-sequence-mainline --retail24 --followup-fleet` |
| 驻军、部分岸炮损失、全图和主线结算 | `--new-sequence-mainline --field-audit --retail-transition --late-dominator --cannon-loss` |
| 断桥、核电站、DX 实弹命中 | `--new-sequence-mainline --dx-bridge-production --reactor-loss` |
| 电厂配对与时间边界 | `--plant-pairs` |
| 独立进程冷读 | 复用舰队专项的隔离档，运行 `--cold-crossing --after-midpoint --retail24` |
| 触发器解释器 | `res://tests/allied_retail_script.tscn -- --first-only` |

全图逐项核对 189 条原始建筑，157 栋在场、31 栋界外、1 栋开局已毁。在场包含 104 栋 Neutral 和 5 栋 BridgeHouse。核对地基、血量、归属、房色、雷达记忆、中立驻军及占领配置。230 条地物中区内 196 条。原地图包逐格审计 9,400 格、981 坡格及 276 个航点，数据差异为零。普通桥覆层为空，任务桥按原建筑清点。工具为 `tools/audit_allied_ends.py`。宿主 Python 缺少 lzokay，本轮用仓库已有 `refs/ts-ra2/src/data/encoding/lzo1x.ts` 解压 LZO 块并校验长度，复用原审计其余所有断言。

专项以游戏命令、快进任务时钟、建筑受击夹具与冷读验证。未做人手自然计时整关或画面对照。截图 0 张。

## 最终后台断言

| 场景 | 通过 | 日志 |
|---|---:|---|
| 逐 ID 与舰队 | 105/105 | verified-fleet.out |
| 结算、驻军、部分损炮与全图 | 85/85 | verified-main.out |
| 断桥、核电站与 DX 命中 | 64/64 | verified-dx.out |
| 电厂配对 | 30/30 | pairs-ok.out |
| 穿越中点新档冷读 | 10/10 | cold-ok.out |
| 上一批穿越中点档冷读 | 9/9 | legacy-mid.out |
| 舰队冷读 | 4/4 | fleet-cold.out |
| 解释器 | 115/115 | raw-ok.out |

以上结果均核对了标准错误为空。上一批中点档来自隔离测试 mf 的 slot3，此时旧版本已完成卖楼交接。首次复测遇到同时修改中的终关脚本缺失方法，待该方法落盘后在同一工程重新验证冷读与解释器。
