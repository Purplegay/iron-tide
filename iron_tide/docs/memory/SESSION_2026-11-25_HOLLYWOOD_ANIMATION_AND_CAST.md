# 洛杉矶建筑动画与任务名册

8 类尤里建筑载入建造序列。补齐工厂四门层、建造场生产层、回收厂工作与第二待机层、碉堡进出驻车层，按可见 SHP 数量切分受损帧。回收厂居民进厂触发 special，碉堡随驻车状态正反向播放。感应器建造序列复用原项目图集，避免破坏高清页尺寸。导出工具 tools/hollywood_animation.mjs，已从 tools/hollywood_yuri.mjs 调用。

从原版规则、地图覆盖和图像导出 data/hollywood_cast.json，工具 tools/hollywood_cast.mjs 的 exportCast(game) 从项目根运行。加入 37 个类型，36 个找到原图像，CALA06 使用程序化建筑回退。原图预置车辆、市民和尤里部队由任务加载，三位演员使用 CLNT、ARND、STLN，各有原版步兵动作和武器定义。NAFLAK 本关价格 20000、电力 0。运行时字段表 docs/memory/HOLLYWOOD_RUNTIME_FIELD_AUDIT.json 记录 148/148 个同编号定义可取。缺席的 TaskForce 引用保持可查询。开局数量不等同于原版存续及触发顺序。

两座基地使用独立波次进度，生产走费用、进度和出口，在四套 Yuri_Base_Assault 原图编成中轮换，车辆沿其移动路点攻移。共享 enemy 资金与电网。当前 90 秒间隔属适配，逐辆派出，未还原原图全部触发和编队集合条件。感应器在通电时探测目标位置落在 15 格内的敌方命令，己方感应器显示连线。

独立 APPDATA 运行 Godot 4.7.2，日志位于 %TEMP%。it-final-anim-states.log 73 项，无脚本错，含满血与 40% 逐层区间、开工、驻车退车、回收厂回落。it-hol-final-orders.log 验证两厂正常排产、出车、路线和感应。it-hol-verify-win.log 60 项，it-hol-verify-loss.log 61 项，均退出 0，无错误。字段测试 it-hol-cast-field.log。测试使用任务大厅和真实场景，加速队列的检测手动推进时间。动画验证读运行时状态，未逐帧像素比对。

奴隶矿场 6 个移动实例可见，部署、奴工采矿及再生机制尚缺。盖特坦克原版车体、炮塔和普通主武器已接，连续射击升档和对空武器仍需补齐。演员武器弹头覆盖、心灵控制、接管后的感应线显示、出击编成全轮换、冷读档和发行包仍待专项验收。
