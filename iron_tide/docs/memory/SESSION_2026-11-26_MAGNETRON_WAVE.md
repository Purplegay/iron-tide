# 2026-11-26｜磁电坦克攻击特效

玩家可见问题：尤里的磁电坦克（`TELE`）对车辆曾从地面原点画通用紫色激光，对建筑不画波、只走通用命中表现。现在攻击车辆与建筑都走专用背景折射磁力波：车辆向炮口推进、建筑从炮口向建筑推进，两端随实际对象移动；停火或丢失牵引后收波，任一端在迷雾中不显示。没有改普通主武器的牵引距离、速度与时长，也没有改副武器的伤害和冷却。精英武器名使用同类波及既有牵引分支，不新增精英升级数据。

## 零售依据

- 本机 Steam `rulesmd.ini`：`TELE` 的 `MagneticBeam`、`MagneticBeamE`、`MagneShake` 均为 `IsMagBeam=yes`，不是 `IsLaser`；`MagneShakeWH` 没有 `AnimList`。`artmd.ini` `[TELE] PrimaryFireFLH=85,0,130`。从 `mapsmd03.mix` 先前提取的 `sov07.map`（SHA-256 `eacf89952cb6e8eacd762f97895a062e0b6bfa16c8f916b901c1e667def266d4`）没有覆盖这四个单位/武器段。
- 同一 Steam `gamemd.exe`（SHA-256 `3e81a61775d2745d1dabe397325ef663cd994ffc194da4e998e3bf5d2d308600`）：`0x6FF5F5` 创建 mode 3 波，不为同炮手反复叠加；`0x762070` 使用四角、模式 3 横向 ±50 lepton、首端提高 50 lepton；`0x762C83` 车辆反向，`0x762CC9` 后建筑正向，活动波侧取 slot 0；`0x762D89` 前沿和 `0x762E88` 后沿每个规则帧推进 0.05。`0x75F020` 初始化距离、正弦和强度表，`0x760190` 按查表位移读背景像素、分别增强红蓝而不增强绿，不绘制实心光束。用系统临时目录 `iron-yr-disasm/inspect.cjs` 和现有 `refs/yr-wave-audit` 反汇编核对。

## 实现与验证

`scripts/units/unit.gd::_fire_shot` 接入 `scripts/core/yr_magnetic_wave.gd` 和 `.gdshader`；读取武器名是因为战役和遭遇战两份尤里数据不经过通用 RA2 光束解析。炮口按 `artmd.ini` 偏移；每辆车只登记一个活动波；背景采样限制在波面周围，迷雾按活动端点的地面坐标判定。`scripts/units/head_games_weapons.gd` 去掉旧激光。没改模型、贴图或玩家存档。

Godot 4.7.2，使用独立 `APPDATA`、`LOCALAPPDATA`、隐藏控制台，命令 `--headless --path <工程> --quit-after 250 res://tests/yr_magnetic_wave.tscn`。从苏军菜单点《首脑游戏》并出击，Battle 内摆放实载单位和建筑，直接调用常规 `_fire_shot`，手动推进视觉规则帧。19/19、退出 0、stderr 空，证据 `%TEMP%/IT-Magna-08d7de87/{out,err}.txt`。验证了主副武器、炮塔加载、牵引登记、建筑掉血、重复开火、移动端点、迷雾、暂停、停止攻击及阵亡清理。只以武器名验证精英分派，没有实打升星；遭遇战使用同套开火路径，未另进一局。

现代着色器沿用原版波面形状、阶段、相位和红蓝调制依据，采样位移为近似；原版 16 位像素查表、逐行正反采样、深度遮挡未逐像素移植，建筑命中点用项目战场美术中心。无头不验证实际 GPU 画面，未与零售游戏并排录像、未从战役自然推进到交战、未打包；也未做牵引升空机制或存档行为的改造。
