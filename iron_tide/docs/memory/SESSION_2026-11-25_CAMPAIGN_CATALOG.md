# 战役生产栏与占领单位排序

HUD 的战役单位目录过滤 R3 系列和 YURIKO。GameData 的单位排序表给五个好莱坞占领产品补上位置。狂风跟在灰熊之后，盖特跟在多功能步兵车之后。尤里新兵、工程师和复制人分别归入相应用途的位置。

Godot 4.7.2 运行 tests/hollywood_campaign.tscn 的 --captured-factory 分支，57 项通过，退出码 0。测试核对实际载具卡顺序、战役目录过滤、占领建筑出兵及失去工厂后的卡片移除。日志在 %TEMP%/IT-CampaignCatalog-check/result.log。验证范围为本地源码和好莱坞关卡，未打包。