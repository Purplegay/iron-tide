# CHANGELOG · RA2 规则迁移 第 4 批（单位语音）

> 本轮口令：**「开始做吧」**（承接上一轮的「单位语音钩子 vs 电力系统」二选一，由我们拍板 = **单位语音**）
> 铁律不变：RA2 是规则唯一事实源 / 判定几何 WYSIWYG / 每步可验证（无头自检 + 有头离屏截图 + 实测日志，跑完删临时工装）。
> 自检结果：**语音链路 PASS**（29/29 断言：数据链 13 + 行为 16）。见 `RA2移植_语音_自检日志.txt`。

---

## 0. 一句话结论

第 3 批让单位**会开枪**了（枪声），但**不会说话**。本批补上后者：
`rules.ini` 的 `VoiceSelect/VoiceMove/VoiceAttack/VoiceFeedback/DieSound/...`
→ `[sound.ini]` 条目 → `LANGUAGE.MIX` 的 `audio.bag` **真实 RA2 语音 WAV**，
并接到 **8 条真实事件**上（选中 / 移动·采集下令 / 集火下令 / 无法服从 / 部署·起身 / 阵亡 / 被碾压 / 建筑阵亡）。

---

## 1. 关键事实：语音与开火音是两套东西

- `[sound.ini]` 的 `Sounds=` 值**带 `$` 前缀 = 单位语音**，**不带 `$` = 纯音效**（沿用第 3 批口径）。
- 命名上极易混淆：`GIAttack`（开火的枪声，第 3 批） vs `GIAttackCommand`（**下达攻击命令时美国大兵的回话**，本批）。
- 语音条目的来源是 **`rules.ini` 单位/建筑小节的 `Voice*` 键**，值即 `[sound.ini]` 的段落名：
  ```
  [E1]  VoiceSelect=GISelect  VoiceMove=GIMove  VoiceAttack=GIAttackCommand
        VoiceFeedback=GIFear  VoiceSpecialAttack=GIMove
        DieSound=GIDie  CrushSound=InfantrySquish
        DeploySound=GIDeploy  UndeploySound=GIUndeploy
  ```
- 载具共用语音集（`GenAllVehicleSelect/Move/AttackCommand/Die`），矿车用 `ChronoMiner*`，
  谭雅/狙击/海豹/间谍/超时空兵各有专属集。建筑基本无 `VoiceSelect`，只有 `DieSound`（如 `GAPOWR=PowerPlantDie`）。

---

## 2. 落地改动

### 管线（generated，禁手改）
| 文件 | 内容 |
|---|---|
| **`ra2pipe/faction.mjs`** | 新增 `VOICE_MAP` + `buildVoice(extra)`，每个单位/建筑输出 `voice:{select,move,attack,feedback,special,die,crush,deploy,undeploy}`（只写存在的键）；自报台账追加语音清单。 |
| **`ra2pipe/sfx_build.mjs`** | 新增 `collectVoices()`（显式遍历 `voice` 块收集 sound id）；**并把扫描范围从 `data/ra2/*.json` 扩到 `data/ra2_*.json`**——上一轮只扫了 `data/ra2/`，而 `ra2_allied.json` 在上一级目录，导致语音全漏。 |
| **`iron_tide/assets/ra2/sfx/`** | **580 个 WAV / 29.02 MB**（本批 **+199 个 / +7.7 MB**，全部语音）。 |
| **`iron_tide/data/ra2/sfx_index.json`** | **580 项**（原 381）。 |
| **`iron_tide/data/ra2/sound_specs.json`** | **233 条**（原 184，+49 条语音条目）。 |
| **`iron_tide/data/ra2_allied.json`** | 19 单位 + 16 建筑，其中 **19 单位 + 2 建筑**带 `voice` 块。 |

### 引擎
| 文件 | 内容 |
|---|---|
| **`scripts/core/ra2_sfx.gd`** | 新增 `voice_id(data,kind)` / `has_voice(data,kind)` / `play_voice(data,kind,pos,throttle_ms)`；`stats()` 增加 `voice_plays` / `voice_misses`；同一 sound id **节流**（近似 RA2 的 `Limit=`，避免框选/群体阵亡叠成机关枪）。 |
| **`scripts/world/battle.gd`** | `_emit_selection()` → `_maybe_select_voice()`（选择签名去重，选择变化时才播）；`_command_move()` / `_try_harvest_at()` → `move`；`force_attack()` → `attack`；新增 `_voice_rep()` / `_play_group_voice()`。 |
| **`scripts/units/unit.gd`** | `_die()` → `die`（`receive_hit` 若 `attack_type=="crush"` 置位 → `crush`）；`order_move()` 被卧倒状态拒绝时 → `feedback`；`_toggle_deploy()` → `deploy` / `undeploy`。 |
| **`scripts/buildings/building.gd`** | `_die()` → `die`（如 `GAPOWR→PowerPlantDie`）。 |

### 设计口径
**一次选择 / 一条命令只播一条语音**（RA2 亦如此；从"有该语音的单位"里随机取一个作代表，
与 RA2 的随机响应一致），而不是每个单位各播一条。

---

## 3. 口径与证据

### 数据链自检（13 项，全部 OK）
```
E1.select → GISelect (6 wav)   E1.move → GIMove (6)      E1.attack → GIAttackCommand (6)
E1.feedback → GIFear (2)       E1.deploy → GIDeploy (3)  E1.undeploy → GIUndeploy (2)
E1.die → GIDie (5)             E1.crush → InfantrySquish (3)
MTNK.select → GenAllVehicleSelect (5)   MTNK.move → GenAllVehicleMove (4)
TANY.select → TanyaSelect (3)  DOG.crush → InfantrySquish (3)   GAPOWR.die → PowerPlantDie (2)
```

### 行为自检（16 项，全部 OK）
```
[OK] 选中 E1 → select GISelect
[OK] 重复 selection 事件不重播 select 语音
[OK] 框选 2 单位 → 恰好 1 条 select 语音（不叠机关枪）
[OK] 移动下令 → move 语音          [OK] 集火下令 → attack 语音
[OK] 部署 → deploy 语音            [OK] 卧倒单位收到移动令 → feedback 语音，且未真的移动
[OK] 阵亡 → die 语音               [OK] 被碾压 → crush 语音
[OK] 建筑阵亡 → die 语音           [OK] 无 voice 数据 → 计 1 次 voice_miss 且不播放
[OK] 音频文件全部命中（a_misses 相对基线 =0）
VOICEPROBE FINAL stats={"plays":10,"misses":0,"voice_plays":9,"voice_misses":1,"cached":10,"pool":32}
VOICEPROBE VERDICT PASS
editor exit=0        battle exit=0
```

### 提取覆盖
```
referenced ids=277 resolved=233 tokens=589
token hits=580 miss=9  sample=;gcamlo1a,… ;$irocdia, irocdib, irocdic
WRITE ok=580 fail=9 total=29.02MB -> iron_tide/assets/ra2/sfx
```
未命中的 9 个与第 3 批**完全相同**（ini 注释行 `;...` + `irocdi*`），本批语音 **0 漏取**（语音勘察 63 个 id / 238 token 全命中）。

---

## 4. 未完成 / 下一步

- **EVA 播报**（`eva.ini` 事件 → `sound.ini`）：与单位语音**不同源**，本批未动。
- **`VoiceSpecialAttack` / `MoveSound`（移动循环音）/ `CreateSound`**：数据已提取，暂未接事件。
- **命中音**：仍等 FX 动画的 `start_sound` 数据（第 3 批抽查 53 个动画全为空）。
- 其余老待办不变：电力系统、老兵等级、苏军阵营运行时、命令集、地形/水 + `MovementZone`、建造耗时公式、超武。
