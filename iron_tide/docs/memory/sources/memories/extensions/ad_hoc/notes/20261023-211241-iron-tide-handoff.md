# Iron Tide 交接更新（2026-10-23）

用户明确要求“记得写交接memory”。本条供合并到 IronTide 专题，纠正旧索引并保留接续入口；不更新 KFramework 的游戏系统记忆。

## 工作区与交付边界

- 实际仓库 `C:/Users/admin/IronTide`，Godot 工程 `iron_tide/`；聊天默认 cwd 虽为 `KFramework_server`，操作必须显式指定 IronTide。
- 当场核实：分支 `codex/ra2-independent`，HEAD `8dfa8310e8a68293a689b9900a5dde39382c4ed6`，origin `https://gitee.com/hly972233/iron-tide.git`。这是当前快照，下轮重新核实。
- 旧 MEMORY 的“非 Git、缺少尤复输入”已过时。现有 Git 仓库、Steam 尤复安装和运行资源；不要重新按缺资源阶段处理。
- 本线程此前已推送运行资源提交 8dfa831；本轮未重新查询远端 SHA。当前大量功能代码、测试及最新载具资源仍未提交，不能称作远端已具备，不能清理/覆盖共享脏改动。
- 玩家启动入口 `C:/Users/admin/IronTide/iron_tide/启动游戏.bat` → `launch_game.ps1`；`-PrepareOnly` 只导入脚本/资源，不启动或关闭玩家游戏。本轮最后返回 Ready。
- 用户已经选定保留 Godot、独立实现原版机制，RA2 与扩展模式分开；不是整库翻译未授权的参考实现。用户偏好直接推进，不逐批重复询问。

## 最新：BGM 仅开战后播放

- 用户规则：“bgm是战斗开始才有”。曲目仍为本地 `assets/music/rock-and-awe.mp3`。
- `scripts/core/music.gd` 仅允许 `context == "battle"` 播放；menu/preparing/results 停止并清零下局恢复位置。菜单重播、开启音乐偏好都不能越过开战条件。
- `scripts/screens/battle_screen.gd` 先 setup 和 `BattleSaves.restore_pending`，再根据 `skirmish/prepared/ended` 决定播放。遭遇战开局播放；战役准备阶段安静，真实 `Events.wave_started` 启动，后续波次不重启；准备/进行中存档按恢复状态区分。结算或离开战场停止。
- `scripts/ui/music_controls.gd` 菜单显示“开战后播放”，重播按钮禁用。原音量/开关持久化、暂停降音量、语音压低音乐和倍速不变调保留。
- `music_regression` 48 项（真实 WASAPI/MP3/PCM、开关、首波、存档、结算）；`music_ui_regression` 26 项（两分辨率与实际控件），合计 74 项通过。
- 证据：`C:/Users/admin/Temp/iron-tide-battle-only-bgm-20261023-{audio-v3,ui-v1}/reports`，两轮 source_unchanged=true、exit=0。客观通过，音频与界面体验仍 pending_user_visual_confirmation。
- 测试陷阱：未播放的音频 bus 可以休眠而没有 PCM 帧，静音检查允许空帧，实际播放必须有非空 PCM；读档同时暂停 world 和 SceneTree，恢复使用真实 `hud._toggle_pause()`，不要只取消树暂停。

## 上一轮：机器人悬浮、载具 32 方向与转弯

- 根因：ROBO 只接两栖通行没有悬浮高度；载具仅 8 方向，转向显示每次跳 45 度；移动控制在 35 度边界突然由约 80% 速度切到零。
- `scripts/units/unit_hover.gd` 接入 `unit.gd`：供电浮起和待机起伏、断电下降、恢复供电继续订单；车体/炮塔/炮口/点击几何共用视觉高度，阴影和地面碰撞不抬升。冻结暂停与停止不漂移保持。
- 本地规则参考 HoverHeight=120、HoverDampen=40%、HoverBob=.04；高度换算和时间曲线是 Godot 视觉适配，尚未完整复刻 HoverBoost/HoverAcceleration/惯性积分。
- MTNK/FV/SREF/MGTK/TNKD/ROBO/CMIN/AMCV 从原 VXL 重导为 32 方向，FV 三种乘员炮塔也为 32 方向；保留原速度、ROT 与 Accelerates=false。
- `ra2pipe/vehicle_facings.mjs <本机尤复目录> <新的外部目录>` 输出候选及来源 SHA256；`allied_ability_art.mjs` 输出 FV 乘员炮塔。整组更新 PNG/JSON、阴影与 unitweapon 炮口，不能只拷贝 PNG；旧基础导出仍可能回退为 8 方向，重导后须补跑这两个工具，README 已记录。
- 最终转弯保留 35 度小半径边界，在 20～35 度区间 smoothstep 减速。试验过扩大到 85 度，造成 200 混编中 E1 卡住；旧版同场景通过，因此已撤销扩大范围。不要恢复该失败候选。
- 最终 3522 项：vehicle_motion 142、unit_muzzle 2682、ground_control 20、traffic 52、yr_robot 200、allied_abilities 198、miner_heading 128、savegame 100。两模式 50/100/200 单位全到位，200 单位约 26.63 秒、停稳无重叠。
- 证据：`C:/Users/admin/Temp/iron-tide-vehicle-20261023-{motion-v2,muzzle-v2,ground-v2,traffic-v2,yr-robot-v2,abilities-v2,miner-render-v2,save-v2}/reports`。当时最终 unit 代码及 voxel/weapon 资源与验证副本字节相符；后续 BGM 修改属于新一轮，不把旧报告说成全部当前源码的重测。
- 实际移动手感与悬浮观感仍 pending_user_visual_confirmation。保留已有部分测试退出的 ObjectDB 残留警告，不称其已解决。

## 更早改动与接续入口

- 本线程已处理战场框选拖到小地图释放时漏选，保留世界开始手势的释放归属；709 项输入/地图/镜头检查通过，详见 `docs/VERIFICATION.md`。
- 当前固定技能槽为 Q 单位固有主动、W 一个玩家装配主动、一个装配被动、E 特殊部署/模式/卸载；不恢复旧 Q/W 重复部署。旧存档内部技能数组按 ID 映射兼容；两模式独立。
- 右键生产首次暂停、再次取消，左键继续；侧栏遮挡相机修整、普攻冷却环、生产完成闪烁等前序功能均在共享脏工作区，不能因只修新问题而回滚。详细范围读 `docs/VERIFICATION.md`、`docs/RA2_PARITY.md`、`docs/ALLIED_ABILITIES.md`。

## 验证环境与命令

- Godot 控制台：`C:/Users/admin/AppData/Local/Programs/Godot/Godot_v4.7.2-stable_win64_console.exe`；Node：`C:/Users/admin/AppData/Local/Author Software/nvm/.nodejs/node.exe`；Python：`C:/Users/admin/AppData/Local/Programs/Python/Python312/python.exe`。
- 本机尤复：`C:/Program Files (x86)/Steam/steamapps/common/Command & Conquer Red Alert II`；已提取规则：`C:/Users/admin/Temp/iron-tide-yr-steam-20261023/rulesmd.ini`。
- 仓库根运行 `./iron_tide/tests/run-navigation-building.ps1 -Suite <suite> [-Render] -RunRoot C:/Users/admin/Temp/<新的唯一目录>`。runner 复制真实工程及独立 custom_user_dir，前后审计源码指纹；运行期间不要编辑被审计的 scripts/scenes/data/shaders/tests/assets。
- 图像/点击/炮口/矿车朝向检查用 `-Render`；miner_heading 纯 headless 会跳过图像断言，0 checks 不能作通过证明。音频 suite 已配置真实 WASAPI 与墙钟计时。
- 验证依赖仅离线 Godot，服务/端口/数据库 none。真实玩家数据在 `AppData/Roaming/Godot/app_userdata/Iron Tide RTS`，测试不得写入；不要结束玩家的 Godot 进程。
- 每轮交付明确源码未提交/是否推送、客观验证和用户体验确认边界。当前无需新询问，下一次按用户反馈继续；提交前重新核实脏改动归属及远端状态。
