# CHANGELOG · RA2 规则迁移 第 3 批（音效）

> 本轮口令：**「一个就开工」**（承接上一轮的「音效 vs 电力」二选一，由我们拍板 = **音效**）
> 铁律不变：RA2 是规则唯一事实源 / 判定几何 WYSIWYG / 每步可验证（无头自检 + 实测日志，跑完删临时工装）。
> 自检结果：**音效链路 PASS**（数据→选择→解码→真实开火播放；单位 + 建筑两条链路）。见 `RA2移植_音效_自检日志.txt`。

---

## 0. 一句话结论

第 2 批里「炮口火光」是**看得见、听不见**的；本批把它补成 **火光 + 枪声**：
`weapon Report=` → `[sound.ini]` 的 sound id → `Sounds=[...]` 随机取一 → **真实 RA2 WAV**，与炮口火光同帧触发。

---

## 1. 素材：声音到底藏在哪（本轮挖出的关键事实）

RA2 的音效**不在 `RA2.MIX`**，也不在常规子归档里。实测结论：

- 在 `LANGUAGE.MIX` 内，有一个容器（内部 hash `0xad29acfa`），里面是音效库的**成对文件**：
  - **`audio.idx`**：`GABA` 魔数 + 条目表（`filename[16] / offset / length / sampleRate / flags / chunkSize`），共 **1153 条**。
  - **`audio.bag`**：16.8 MB 原始音频数据块（`offset/length` 指向这里）。
- 编码：**全 22050 Hz**；`flags & 0x08` = **IMA ADPCM**（1126 条 mono + 2 条 stereo，`chunkSize=512`，`samplesPerBlock=1017`），`flags & 0x02` = PCM16 直通（25 条）。
- 事实源对照：`refs/ts-ra2/src/data/IdxFile.ts`、`AudioBagFile.ts`、`WavFile.ts`（Chrono Divide 权威实现）。
  - `[sound.ini]` 的 `Sounds=` 里的名字 **就是** bag 里的文件名（去掉 `$` 前缀后）。

> 排查过程中确认：全库搜 `RIFF`/`WAVEfmt` 只有这一处音频容器；`RA2.MIX` 内 **0** 个 RIFF。所以音效**只能**从这里取。

---

## 2. 引擎/Godot 的一个硬事实

**Godot 4.7.2 不支持 IMA ADPCM 的 WAV 导入**（实测 `AudioStreamWAV.load_from_file` 报
`Format not supported for WAVE file (not PCM)`）。

→ 因此管线**统一解码为 PCM16**（自己实现 IMA/DVI4 解码），产出标准 16-bit WAV，Godot 直接可播。

---

## 3. 落地改动

### 管线（generated，禁手改）
| 文件 | 内容 |
|---|---|
| **`ra2pipe/sfx_build.mjs`**（新） | 打开 `LANGUAGE.MIX` → 取 `audio.idx`/`audio.bag` → 解析 `GABA` 索引 → **IMA ADPCM 解码为 PCM16** → 写 `assets/ra2/sfx/*.wav`；同时导出 `data/ra2/sfx_index.json`（名字→文件/规格）与 `data/ra2/sound_specs.json`（`[sound.ini]` 条目）。支持 `stats/needed/all`。 |
| **`ra2pipe/faction.mjs`** | 运行时武器新增 **`report`**（来自 rules.ini `[Weapon] Report=`），供开火音效接线。 |
| **`iron_tide/assets/ra2/sfx/`**（新） | **381 个 WAV，21.3 MB**（`needed` 模式：只产数据里实际被引用的音效）。 |
| **`iron_tide/data/ra2/sfx_index.json`** | 381 条：文件/采样率/声道/帧数/时长。 |
| **`iron_tide/data/ra2/sound_specs.json`** | 184 条：`Sounds` 列表 / `Volume` / `Range` / `Loop` / `Priority`。 |

### 引擎
| 文件 | 内容 |
|---|---|
| **`scripts/core/ra2_sfx.gd`**（新，autoload `Ra2Sfx`） | `AudioStreamPlayer2D` 池（32）；`play(id,pos)` 随机取 wav、缓存 `AudioStreamWAV`、按 `Volume` 转 dB、按 `Range=格×55px` 设 `max_distance`；`play_weapon(weapon,pos)` 读 `report`；`stats()` 供探针。 |
| **`scripts/autoload/game_data.gd`** | 新增 `_load_ra2_sfx()` + `ra2_sound_spec/files/path/volume/range_cells`、`has_ra2_sound()`。 |
| **`scripts/units/unit.gd`** | `_fire_shot()` 在 `_spawn_muzzle_fx(muzzle)` 后同帧 `Ra2Sfx.play_weapon(weapon, muzzle)`。 |
| **`scripts/buildings/building.gd`** | `_fire()` 在 `_spawn_muzzle_fx(...)` 后同帧 `Ra2Sfx.play_weapon(weapon, muzzle)`。 |
| **`project.godot`** | 注册 autoload `Ra2Sfx="*res://scripts/core/ra2_sfx.gd"`。 |

---

## 4. 口径与证据

- **`Volume=`**：`[sound.ini]` 百分比 0..100 → 归一为线性 0..1 再 `linear_to_db`。
- **`Range=`**：格 → `×55px` 作 2D 衰减 `max_distance`。
- **`Sounds=[...]`**：多文件**随机取一**（RA2 语义，避免机械重复）。
- 覆盖：数据里被引用的 **390** 个音效名 → **381 命中**（未命中的 9 个为 ini 注释行 `;...` 与个别语音，均非单位开火音）。

### 自检输出（真实开火）
```
SFXPROBE id=GrizzlyTankAttack files=3 fmt=1 len=... vol=... range=...
SFXPROBE placed GAPILL report=PillboxAttack
SFXPROBE placed ATESLA report=PrismTowerAttack
SFXPROBE t=2400 combatants=... armed=... stats={plays:57, misses:0, cached:9, pool:32}
SFXPROBE VERDICT PASS
```

---

## 5. 未完成 / 下一步

- **单位语音**（`$` 前缀的 `VoiceSound/VoiceAttack`）：数据已在 `sound_specs.json`，但需 UI/命令钩子（选中、下令、阵亡）才能接。
- **命中音**：本轮抽查的 53 个 FX 动画 `start_sound` **全为空**，故未接（RA2 命中音多挂在其它动画上）。
- **Master 音量设置项**、**3D 距离衰减调参**（现按 `Range=格` 线性近似）。
- 其余老待办不变：电力系统、老兵等级、苏军阵营运行时、命令集、地形/水 + `MovementZone`、建造耗时公式、超武。
