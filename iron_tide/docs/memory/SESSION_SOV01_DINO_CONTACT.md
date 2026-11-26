# 苏军第一关侏罗纪充能防守

零售地图触发器索引收录 SP3.9_Reinforce_Dino1 和 SP3.10_Reinforce_Dino2。移植脚本每 10 秒交替从航点 69、70 派敌对霸王龙。实测旧版直攻时光机的命令很快清空，两路满血停在入口直到倒计时结束。原测试允许场上的中立霸王龙满足出兵断言。

scripts/world/time_shift.gd 改用战场寻路向时光机旁的守军集合点 68 攻击移动。tests/time_shift.gd 收紧既有断言，新增 --dino-contact，按出生位置区分两路敌军，各自须在己方视野内受伤。

Godot 4.7.2 --headless --fixed-fps 60 tests/time_shift.tscn -- --dino-contact 从战役菜单出击，测试跳过影片、脚本清岸防和碉堡，用工程师接管四厂。进入侏罗纪后自然推进物理帧。入口 69、70 分别在充能剩余 97.13、85.73 秒实际接敌，退出码 0。日志在 %TEMP%/IT-S01-dino-contact/both 及 botherr。验收到两路首次交火；本次未验证守军全部撤走后的行为、旧充能档或发行包。
