# 第七关房色与首轮接敌

零售 mapsmd03.mix 中 Brief:Sov07md 的 Player House 用 DarkRed，BadGuy1/2/3 House 分别用 Purple/Purple2/Purple3。rulesmd.ini 的 8 位 HSV 分别为 (0,230,255)、(201,201,189)、(211,201,189)、(191,201,189)。修正关卡涂装、小地图与己方识别描边；被解放的单位和工厂切换到玩家红。驻军和进攻编组在写入翼别后刷新涂装，读档恢复翼别后刷新。中立默认 Grey。

逐行检查原图 Units/Infantry/Structures。距 17 号集合点最近的 BadGuy 静态记录是 (144,103) 的狂兽人，直线 45.3 格。此前全体非采矿驻军一律原地待命，遗漏 116 个 Area Guard。现在按每条原图记录区分区域警戒与原地警戒。45/75/90 为展开后的编组出发时间，未展开 120 时三路出兵；均为任务计时，与抵达时间有别。

Godot 4.7.2 的 --contacts 实际场景专项 15 项通过。主动触发三支首轮编组、保留战场物理与寻路，每路至少一人锁定我方目标，首次全部接敌之前各队离集合点最近约 5.0、12.8、13.4 格。此分支没有实等各自然倒计时。图形窗口 --opening 28 项和全场景回归 41 项通过。日志 %TEMP%/s07contact-final.log、s07-color-window.log、s07-color-full.log。截图 [第七关原图红色开局](evidence/HEAD_GAMES_DARKRED.png)。未重放用户截图时刻或导出安装包。

后续修正：第七关己方识别描边移除按房色取色的特例，沿用本方黄色、友军白色与攻击目标红色。Godot 图形窗口从战役菜单启动 tests/head_games.tscn -- --outline，确认基地车本体为 DarkRed，描边着色器为 OWN_COLOR。验证对象为开局基地车，日志位于 %TEMP%/IronTideS07Outline/out。
