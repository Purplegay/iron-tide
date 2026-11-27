# 谭雅 Sapper：载具车身闪一下再炸

## 零售依据与表现取舍

- 直接核对 `.validation/allied-ends-20261126/source/rulesmd.ini`（Steam 尤复；SHA-256 `3d341ef8a13a4b5ab24af2eef48ac94931ac2bb87d950fe3330a07e2d25672ef`，与能力表的 source_sha256 相同）：`[TANY]` 普通/精英副武器均为 `Sapper`，使用 Invisible、Mechanical、SealPlaceBomb；Mechanical 对 light/medium/heavy 是 100%，无 AnimList。`[MTNK]` 列出的死亡动画为 TWLT070、S_BANG48、S_BRNL58、S_CLSN58、S_TUMU60。建筑 C4 另走 Time/Warhead 规则（C4Delay=.03 分钟，C4Warhead=Super）。不要拿本地 RA2 原版的 `extracted/rules.ini`（Sapper=Invisible5/Super）替代尤复。
- 本地 `refs/ra2yr-resource` `b01d3cf` 的 `src/structure/building.hpp` 有独立 C4Timer/C4Applied/C4AppliedBy；`ObjectClass::Flash` 目前为仅请求重绘的占位，不能证明零售载具特效。`refs/ts-ra2` `898d891` 的 `Building.ts`、`HighlightAnimRunner.ts`、`unit/ExtraLightHelper.ts` 提供对象增亮、不改色的表现参考；该触发是建筑有 C4，不是载具 Sapper。载具的半强增亮和长度 2/15 游戏秒是 Iron Tide 本轮近似，不是零售 EXE 的已证帧序；未运行原版窗口逐帧对比。

## 实际修改

- `scripts/units/unit.gd`：正常下令让谭雅近身，仍用 Sapper 在命中时结算伤害、立即死亡、取消碰撞和发击杀信用。仅由 Sapper/Mechanical 造成实际阵亡、且走原生贴图与房色材质的非空中、非步兵单位保留短暂亮起的车身；随后走已有死亡爆炸和声音。房色材质按目标复制，不改邻居，不造额外的存档炸药状态；快照仍排除已死单位。不把爆炸伤害、死亡武器、残骸碎片或乘员弹出的规则时点延后。Sapper 不再为 Unit 生成空弹头的通用命中圆环；非致死不启动阵亡闪光。建筑 C4、工程师拆弹、FakeC4、主动技能均未改。
- `shaders/house_remap.gdshader`：目标贴图增亮，保留房色/贴图透明度、排除黑色阴影和普通 UI 图元。未新增/重烘素材。
- `tests/commando_attack_regression.gd`：新增非致死命中、立即击杀/碰撞/击杀信用、独占材质、先闪后爆且只生成一个原版爆炸的检查；可用 `-- --sapper-only` 单跑。

## 验证

- Godot 4.7.2，无头、独立自定义用户目录、真实 Battle 场景；对 RA2 与扩展模式下达玩家攻击指令，夹具推进物理步。`--headless --path <隔离项目> res://tests/commando_attack_regression.tscn -- --sapper-only` 22/22；全套一次干净 136/136；`res://tests/yr_vehicle_death_regression.tscn` 394/394，以上 exit 0 且 stderr 空。证据（仓库父目录）`.validation/sapper-flash-20261127-135838/` 中 `sapper-only/`、`candidate-1/`、`yr_vehicle_death_regression/`。
- 突击队全套其余轮次曾出现建筑安放/拆弹不稳定；未接闪光的隔离对照（本批所涉文件回到 HEAD，其余脚本保留采样时工作树）也复现两项断言，另有干净 126/126。生产建筑逻辑和该段测试断言未改。另一次候选虽断言全过，stderr 有工作树并行修改的 `expedition/run.gd:571` 编译错误，不作为通过证据。未改玩家存档，未打包。
- 没有打开有头窗口，未验实际像素观感、不同缩放/水面、贴图特殊车型和零售确切时长；专项以灰熊坦克为样本，不代表所有舰艇、伪装、护盾、英雄残骸或战役流程均实测。
