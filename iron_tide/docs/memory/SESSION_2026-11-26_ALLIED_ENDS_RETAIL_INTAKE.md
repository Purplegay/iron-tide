# 尤复盟军首末关：零售资料与地形阶段交接（未开放出击）

## 原图与生产改动

Steam 本机零售 `battlemd.ini` 指定首关 `ALL01UMD.MAP`，终关是 `ALL07SMD.MAP`（不是 ALL07UMD）。两图取自 `mapsmd03.mix`，容器 SHA-256 `6c36a0af05e2e9f86967308c77cf90fae9976d920e320aad8b9e4aa2e99e86a3`。

|关卡|零售成员 / SHA-256|剧场与 LocalSize|格数 / 坡格|原始航点及入口|
|---|---|---|---|---|
|01 Time Lapse|`0x3a6f0ac2` / `dee38769f2247a85908705486c175ef14a4cf90437899defe7c8b4c0d1c51fb0`|NEWURBAN / 12,5,47,100|9400 / 981|276 个（22 个在可玩界外），HomeCell 14 → (47.5,82.5)|
|07 Brain Dead|`0x9fd0367f` / `0ec687c320382e4c02cf66eec0153b713e56c4449fab7d29b5a19b61bf10e4f3`|SNOW / 15,13,100,110|22000 / 1539|68 个（10 个在可玩界外），HomeCell 79，坐标见 audit.json|

- `../ra2pipe/native_map_source.mjs --allied-ends` 从该容器读取指定成员，核对剧场，记录容器和地图 SHA，提取 TMP、剧场规则与调色板。不写 Steam 安装目录。
- `../ra2pipe/native_maps.py` 为战役保留全部航点及界内标记，开场位置使用 `Basic.HomeCell`，而非套用遭遇战 0–7 号出生点。这两张原图都没有大厅预览，候选版从地形生成占位预览，不进入遭遇战目录。
- `tools/audit_allied_ends.py` 从地图包重建格坐标、逐格核对 tile/sub/格高及零售 TMP 地形类和坡型，核对航点、桥 overlay 和隔离目录。逐 ID 关联 Triggers/Events/Actions/Tags/CellTags，另导出房、队伍、编组、脚本及 AI 定义。只建立核对索引，不是触发器运行实现。
- 候选地形与原图索引留在 `iron_tide/.validation/allied-ends-20261126/`；未写入正式 `assets/maps/yr` 或 `data/maps`，未改战役菜单、任务运行、CG 进度或用户存档。原苏军 `yr_time_shift` 正在有其他改动，本轮未碰它，也不能用它替换盟军首关。

## 下一阶段必须从玩家操作核对

|环节|首关 Time Lapse|终关 Brain Dead|
|---|---|---|
|开场与入场|`A01_F00e`；对 `Camera_Start`、岸炮与航空开场、`A01_p01`、图外入场和实际交还控制逐项走验。盟军房为 DarkBlue；已有四门盟军 `GTGCAN`，时光机 `CATIME01` 开局属于 Americans，八座可抢占的 `CAPOWR01..08` 属 PowerHouse；不是苏军版的登陆夺取盟军时光机。|`A07_F00e`；`Eva_Briefing` 引用 `A07_p01`。火地岛 `Special` 房有 64/256 耐久的 `NACNST` 在 (82,123)。实际验证接管、按本关科技造 `NARADR`、雷达完成才进入超时空基地车和伴随部队链。|
|任务与中断|占领电厂、供电、保护时光机、进入过去、打掉恶魔岛控制器。重点验证电力增减/敌方抢占、谭雅死亡、机器被攻击或毁坏、供电目标与上岛路径；具体失败或替代路线从触发链推导，不能把任一死亡直接硬判为失败。|移交火地岛基地、超时空基地车与护卫通行和展开、摧毁南极控制器、清剿尤里。`YAPPET`/`YAGNTC` 不在开场 Structures；`0460BDBC` 走动作生成。核对 DarkBlue 玩家、DarkRed 友方基地与三个分别为 Purple2/Purple3/Purple 的尤里房，核验敌方各自经济、生产、AI 条件和早拆关键目标。雷达不是直接胜利，摧毁控制器也不是直接胜利。|
|桥与坡|两图标准 BRIDGE/LOBRDG/RAILBRDG overlay 都为零，未见 CABHUT；首关不能据此写“无桥”。BridgeHouse 的七个金门大桥任务建筑沿 **u=58**：v=39 `CASANF14` 256/256（界外），42 `CASANF13` 256/256，45 `CASANF12` 256/256，48 `CASANF04` 64/256，51 `CASANF11` 64/256，54 `CASANF10` 0/256，57 `CASANF09` 64/256。参照 `Check_BridgePiece02`、`BackBridge_Gone`→`Kill_AllBackBridge`；仍须结合零售 SHP 和动作核查非 BridgeHouse 的 CASANF 景物（特别是道路/水边），逐端查桥头、宽度、跨段不越断口、分层遮挡、损毁、修复是否适用及存读档。|按原图 overlay 与桥机构建筑检查无同类桥记录；仍从实际雪地战场核查海岸、斜坡、跨海/空投位置。不能以纹理扫描代替道路或车辆路径验收。|
|CG、声音与字幕|`movmd03.mix` 内 `a01_f00e.bik`（`0xf21d4216`），另追战中雷达视频索引与音轨；对 `evamd.ini` / `soundmd.ini` 做字幕、自然结束、跳过、续音中途及独立进程恢复。|`a07_f00e.bik`（`0xff033251`），`Basic.PostScore=A08_F00e` 对应 `a08_f00e.bik`（`0x0e0869dc`）。从结算继续到片尾并返回菜单，测自然结束、跳过、两影片挂接间隙冷读与收录，不只测播放器创建。|

记录覆盖：首关 334 条关联触发器、278 个 CellTags、102 支 TeamTypes、91 份 TaskForces、94 套 ScriptTypes、62 个变量、165 个全局 AI 开关覆盖；终关 88 条关联触发器、118 支队伍、108 份编组、72 套脚本、31 个变量、84 条本关 AI 条件、249 个 AI 开关覆盖。索引内保留原记录，数量不代表实现或逐条实机通过。

## 复跑与未验范围

在 `iron_tide/` 下运行，下例 Python 要用已装 lzokay、Pillow 的解释器：

```powershell
$out = '.validation/allied-ends-20261126'
node ../ra2pipe/native_map_source.mjs '<Steam 尤复目录>' "$out/source" --allied-ends
python ../ra2pipe/native_maps.py "$out/source" "$out/bake"
foreach ($id in 'yr_all01umd','yr_all07smd') {
  python tools/bake_native_slopes.py "$out/source" "$out/bake/data/maps/$id.json" "$out/bake/assets/maps/yr/${id}_terrain.png" "$out/bake/assets/maps/yr/${id}_slopes.png"
  python tools/check_native_terrain.py "$out/bake/data/maps/$id.json" "$out/bake/assets/maps/yr/${id}_slopes.png"
}
python tools/audit_allied_ends.py "$out/source" "$out/bake" "$out/audit"
python -m unittest discover -s ../ra2pipe -p test_native_maps.py
```

审计 31,400 格、2,520 坡格，格高、图块、子块、地形类别和坡型均无差异。现有导入器测试 10/10 通过。预览只目视了总体地图布局。坡面候选 PNG 检查：首关扫描 715 格，89 个告警归为 16 处；终关扫描 3521 格，2 个告警为 1 处 `(152–153,48)`，日志及分组在 `audit/`。尚未于零售/移植战场同机位判定，勿以脚本退出 0 当成画面验收。当前重采样仍是平面近似。

没有验收出击、战斗/生产、胜负、CG/语音/字幕、失败分支、实车桥坡、独立进程关键节点冷读或新增单位中文全员截图。正式开放前按 `YR_CAMPAIGN_PORTING.md` 全部执行；需要有头实景时先征求同意。没有打包或提交。
