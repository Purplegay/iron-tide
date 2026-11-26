# 好莱坞高架桥与科技限制

ALL02UMD.MAP 来自 Steam 安装目录 mapsmd03.mix。Americans 的 TechLevel 为 10。PCV、GAROBO、GAYARD、YAYARD、TANY、GAWEAT 的地图覆盖为 12。GTGCAN 为 7，RequiredHouses 为 Americans，前置为 RADAR、GACNST。GameData 接入本关生产、建筑选址和国家资格检查。

地图已有六段 BRIDGE1，共一百个原版桥片。Ground 在本关改用原版无桥地面图，把桥片画在独立高架层。每个桥片的交通占地沿原图 ry 方向三格。通过桥头的地面车辆按三格引道渐升，横穿街道的车辆按桥下层排序。三格坡长为移植表现取值。桥片用已有损坏帧和断桥状态更新。寻路与碰撞仍使用工程现有的单层网格，不能单独规划上下两层路线。

Godot 4.7.2，隔离 APPDATA，tests/hollywood_campaign.tscn -- --bridge-tech。原版开局无头初测 17 项通过。调整端部坡度后，--growth --bridge-picture 窗口测试 18 项通过。测试从战役指挥室进入，用同一辆坦克移动到指定格验证引道、桥面和桥下排序，传入断桥状态核对图层。人工查看窗口截图并修正首轮截图中的桥端缝隙。日志 %TEMP%/holly-bridge-window.log，截图 %TEMP%/hollywood-bridge-field.png。未测试旧存档中已经排队的产品、两层交叉碰撞、所有相机角度或打包程序。
