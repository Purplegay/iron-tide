# 尤复盟军清单核对与战斗要塞

2026-10-26，实际工程 `C:/Users/admin/IronTide/iron_tide`。继续保留 Godot、RA2 / 扩展模式分离。

## 清单结论

以本机 Steam `rulesmd.ini` 的单位定义、生产前置及国家限制对照运行包；
不能仅按 Owner 包含 Americans 判断盟军普通生产单位，因为秘密科技和工程师别名也有广泛 Owner。

| 范围 | 当前工程 |
|---|---|
| 尤复新增重装大兵 GGI | 已有，兵营生产；机枪 / 部署导弹、对空、E 部署 |
| 尤复新增机器人坦克 ROBO | 已有，战车工厂生产；需要 GAROBO，供电控制与两栖悬浮 |
| 尤复新增战斗要塞 BFRT | 本次补入；此前生产项、资源和 OpenTopped 逻辑均缺失 |
| 机器人控制中心 GAROBO | 已有，主建筑栏；控制 ROBO 的可用状态 |
| 常规步兵 | E1、ENGINEER、JUMPJET、GHOST、SPY、CLEG、TANY 已有；盟军警犬沿用 DOG ID，未重复加入 ADOG |
| 国家特色 | 英国 SNIPE、德国 TNKD、韩国 BEAG 已有；沿用现有国家限制 |
| 地面载具 | AMCV、MTNK、CMIN、FV、SREF、MGTK、SHAD 已有；SHAD 按原版由战车工厂生产 |
| 海军 | LCRF、DEST、AEGIS、DLPH、CARRIER 已有；航母子机 HORNET 通过舰载系统生成 |
| 固定翼 | ORCA、BEAG 已有；机场生产 / 补弹 |
| 秘密科技 | CCOMAND、PTROOP 已有单位定义，但实验室渗透解锁链未完成；CIVAN 等跨阵营秘密科技不能算普通盟军单位已齐 |

“单位已存在”只表示定义、资源与入口存在，不代表所有原版能力已完整复刻。
v0.4已补基础GI民居驻军、工程师修桥、间谍雷达/超武渗透；实验室窃密此前已完成。
能力边界及驱逐舰反潜机等剩余缺口见 [特殊机制交接](SPECIAL_MECHANICS.md) 与 [ALLIED_ABILITIES.md](ALLIED_ABILITIES.md)。尤里阵营完整兵种不在本次盟军补齐范围内。

## 战斗要塞实现

- 战车工厂 + 盟军作战实验室解锁，成本 2000、生命 600、重甲、Speed=4、Sight=6、ROT=5。
  沿用模式时间比例和逐步扣费；扩展模式基础 40 秒，RA2 模式 84 秒。
- 原版 20mmRapid / HARVWH / InvisibleLow 与 GUNFIRE，通过独立 YR_ 名称空间加载。
- 5 个步兵席位、SizeLimit=2；单位右键上车，E/D 或点击已单选且载人的车体卸载。
- OpenTopped 乘员保留独立武器、冷却、连发和军衔，载具移动时仍可开火。
  GI/GGI 使用部署武器而不改变自身部署状态；射程 +2 格、伤害 ×1.2。
  工程师/间谍不凭空获得武器；空地目标仍按各乘员武器筛选。
- 鼠标攻击光标与载具追击考虑乘员能力；有 GGI 时能指定飞机，车体主机枪仍不能对空。
  遵守载具停火/还击姿态。乘员射程进入载具视野，乘员开火暴露载具位置。
- 超时空兵沿用抹除通道，车内按原参数 OpenToppedWarpDistance=7 限制维持距离。
  卸载释放抹除；载具被毁清理乘员。射击口按座位分开，未宣称与原版 FLH 逐像素一致。
- OmniCrusher 接入实际移动接触，允许碾压敌方普通地面载具；友军、空军、海军、
  OmniCrushResistant 单位（包括另一辆 BFRT）受保护。围墙压毁导航和桥下高度限制尚未实现，
  不把源字段存在等同这些地图机制完成。
- 满载、乘员引用与冷却通过原存档图保存。仅增加“原单位表移除 BFRT”的精确兼容指纹，
  允许此次新增前的兼容存档；其他规则变更仍被拒绝，不关闭版本/校验/白名单检查。

## 来源与复现

本机源：`C:/Program Files (x86)/Steam/steamapps/common/Command & Conquer Red Alert II`。
`rulesmd.ini` SHA256：`3d341ef8a13a4b5ab24af2eef48ac94931ac2bb87d950fe3330a07e2d25672ef`。
原版 OpenTopped 参数与 [Phobos 的原引擎运输挂钩](https://github.com/Phobos-developers/Phobos/blob/develop/src/Ext/Techno/Hooks.Transport.cpp)
交叉核对；Phobos 自定义扩展选项不冒充原版默认行为。
用户给定 RA2YR_ReSource 的 EnteredOpenTopped / ExitedOpenTopped 在本地参考中仍是占位，
没有复制占位实现或 ChronoDivide 派生源码。

```powershell
node ra2pipe/yr_fortress.mjs '本机尤复目录' '新的工程外候选目录'
python ra2pipe/yr_guardian_audio.py '新的工程外候选目录' --pack yr_fortress --namespace yr_bfrt
```

只发布候选 `project/data/yr_fortress.json` 和 `project/assets/` 中的 BFRT 资源，
不覆盖候选 `data/ra2/` 的整套归一化表。32 朝向车体/阴影、头像、32 个炮口锚点、
5 组 / 23 段原始声音。运行代码为 `scripts/units/open_topped.gd`，沿用真实 Unit 武器/运输/存档链。
本轮候选：`C:/Users/admin/Temp/iron-tide-bfrt-export-20261026-v1`，含原档案来源和 SHA256。

专项 `yr_fortress_regression` 覆盖两模式实际生产、满载/非法装载、真实空地命中、独立冷却、
停火/还击、乘员视野/暴露、满载存读档、旧指纹兼容及其他规则改变拒绝、抹除和碾压。
鼠标入口另由 `boarding_cursor_regression` 覆盖真实右键上车和左键卸载，并保存渲染截图。
最终检查数和路径见 [VERIFICATION.md](VERIFICATION.md)。实机画面、语音与手感仍是
`pending_user_visual_confirmation`。本次未推送，未更新旧朋友试玩 ZIP。

## v0.2.9.1 卧倒步兵与路径交接 · 2026-10-27

根因：local_traffic 正确禁止移动己方部署步兵，但 PathService 原先只读取地形/建筑网格，路径仍穿过部署阵列。Battle.path_for_unit 为地面单位收集同阵营、存活、未上车的部署单位，结合双方碰撞半径生成本次请求的临时阻挡；PathService 复制网格后标记，保留起点格以允许接触中的车辆退出。Unit.set_deployed 通知 Battle 增加路径版本，已有移动命令下次转向时重新寻路。没有通过强制起身、取消友军碰撞或提高速度解决堵路。

deployed_traffic_regression 覆盖 RA2/扩展模式、15 名混合 GI/GGI、开阔地/建筑旁、事先部署/车辆距前排40px时部署，验证实际行驶到达、路径半径、姿态位置保持、无友军伤害、速度上限、起身移除临时阻挡与公共地形不变。最终证据及关联回归见 VERIFICATION.md。该流程不是任意密度、无路可走场景的可达性保证；原截图局面的实际手感仍为 pending_user_visual_confirmation。

## v0.2.10 运输容量标识
scripts/ui/transport_indicator.gd 在 Battle._draw_hp_overlay 接入，依据 logistics.capacity 泛化，无新增载具ID白名单。当前可装载单位 BFRT/FV/SHAD/LCRF 都覆盖；航母舰载机属于 squadron，不冒充乘员。
选中/悬停的己方运输单位，在血条下显示全部容量格，未占用用empty。读取存活且embarked_in指向该载具的实际passengers，按passenger_size展开；首格按本机原规则Pip（小写归一，未知默认green），额外Size格white。纯读取，不调用会清理列表的used_capacity，不改变运输、卸载、存档或血量。隐藏/死亡/敌方/被装载的载具不显示。
原素材来自本机Steam尤复PIPS2.SHP帧0～5和PALETTE.PAL；ra2pipe/transport_pips.mjs可重导出到新目录，来源哈希见assets/ra2/pips/cargo/source.json。帧位交叉参考 https://github.com/OpenRA/ra2/blob/master/mods/ra2/sequences/misc.yaml 。这是独立Godot绘制，没有复制参考引擎逻辑。原4x4素材以最近邻2倍显示为固定8x8屏幕像素，每12格换行；使用现有弹药锚点，随飞机高度移动，不受等距缩放挤压。
两模式真实装载/满载/卸载、颜色/像素、载具Size占位、悬停/选择、空中高度和敌方隐藏边界见transport_indicator_regression。实际用户观感待确认，详见VERIFICATION。
