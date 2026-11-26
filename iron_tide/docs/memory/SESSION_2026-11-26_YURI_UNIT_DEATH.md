# 2026-11-26 尤里单位死亡与飞碟坠毁

## 原版与实际修改
- 依据 Steam 零售 YR `rulesmd.ini` / `artmd.ini`；步兵帧可复查 `../refs/yr-death-audit/20261029/audit-final.json`，死亡规则与媒体清单在 `data/ra2/death.json`。`DISK` 是体素机身加旋转部件，没有单独 SHP 死亡条；原规则 `Crashable=yes`、`TiltCrashJumpjet=yes`、`JumpjetCrash=15`、`DeathWeapon=BlimpBombEffect`、`DeathWeaponDamageModifier=.1`、`MaxDebris=14`。原弹头 `BlimpHEEffect`，基础坠毁弹头伤害 `250×0.1=25`（落点距离及护甲另计）。
- `unit.gd` 将正常空中死亡的飞碟交给已有坠机记录；战斗单位立即死亡退出，机体独立下落，到地面才爆炸、生成碎片并结算地面伤害。超时空抹除不坠毁。无高度时沿用即时爆炸。`kirov_crash.gd` 存机种、旋转部件朝向和弹头；继续识别老 `kirov_crash` 记录，缺机种按 `ZEP`。基洛夫保留原武器及老兵伤害路径。飞碟沿用现有 Jumpjet 速度换算和屏幕倾斜适配，非逐帧零售引擎复刻。
- `soundmd.ini` `[FloatingDiscDie]` 指向 `vflodiea`、音量85；从 `langmd.mix/audiomd.mix` 的音频索引及数据取出，以现有 PCM16 解码管线转换。资源 `assets/ra2/sfx/head_games/vflodiea.wav`（22050 Hz、单声道、36901帧），SHA256 `fb2639dab87cfed65beb38a3e76e67d6a7bc6ff4ffa3410137254ef7e595b972`，映射在 `data/ra2/head_games_audio.json`。未新增或重烘视觉贴图，复用机身和旋转部件已有32向原 VPL 2× 贴图，实际战场有头截图已查看。

## 核对结果
- `tests/yuri_death_regression.tscn` 从真实战斗场景触发致死伤害，覆盖 `data/yr_yuri.json` 的全部17个单位（含雷鸣潜艇导弹 `CMISL`），另带战役奴隶 `SLAV` 与展开的奴隶矿场 `YAREFN`。7种步兵逐条检查真实致死弹头选中的 `Die1/Die2`、零起播和原版帧长/贴图覆盖；10种其他地面/海上单位和导弹检查原版爆炸节点确实生成。`SMON` 是原版另一图像/原型条目，项目运行时是 `YAREFN` 建筑，没有可生成的 `SMON` 单位。飞碟检查5个原爆炸贴图、原音效可加载、机体转动下降、不提前爆炸、暂停、存档还原、地面目标受伤而空中目标不受伤、碎片上限、一次性触地和超时空抹除。
- Godot 4.7.2 隔离用户目录，尤里回归无头与有头各 68/68、退出0、stderr空；既有苏军航空回归 68/68、退出0、stderr空。证据 `.validation/yuri-death-20261126/`，`disc-falling.png` 中间蓝边飞碟是坠落中的机体，顶边紫边是仍活着的对照。地面爆炸以回归里的原版特效节点与伤害结果为准，读档后截图不适合作为爆炸视觉验收。QA 配置已归档到证据目录，未留在工程根。
- 不把这次覆盖写成所有死亡分支已复刻：未逐个验所有尤里建筑、所有特殊弹头、潜艇潜航时死亡、飞碟落水与复杂地形或冷启动读档；有头渲染使用 Dummy 音频驱动，验证的是原片段可加载而非耳听。没打包、没改玩家档。