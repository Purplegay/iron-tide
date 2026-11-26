# 好莱坞与虚荣 · 单关试演

大厅战役列表新增 yr_hollywood，使用尔湾原生地图、盟军基地及苏军守军。NAREFN 代演四座回收厂，首次拆厂触发尤里通讯，每座回收 500 资金，第四座拆除后切换目标，敌方建筑清空获胜，盟军建造场丢失失败。数字为试演设定。状态随 allied_state 保存。地图与任务档案、通讯和回收资金的触发时机经过改编。

## 原作机制依据

- 本机 Steam 版 mapsmd03.mix 中的 ALL02UMD.MAP。四个 Grinder1_Gone 至 Grinder4_Gone 标志汇入 Grinders_Gone，动作 0CDDC84C 播 Mis_xA2_EvaGrindersGone 并启用 094D906C，后者播放新目标提示并显示 MISSION:YuriBase。
- To_Grinder1_Beach_Female 等队伍脚本组织居民前往回收厂。Stallone_Discovered、Change_Arnold 各自有部队动作和人物通讯。此类居民路线与人物支线可供后续扩展。
- langmd.mix 的 RA2MD.CSF 包含简报、目标与回收资金提示。evamd.ini 指定 xa2ev01、xa2yu01、xa2ev06 三条原声，langmd.mix 内相应 WAV 解码为 PCM 后存入 assets/ra2/hollywood。中文屏显按行动和说话人编写，其中包含测试用替代建筑说明。

## 验证

Godot 4.7.2 无窗口运行 tests/hollywood_campaign.tscn，临时 APPDATA。任务卡按钮切入实际战场。胜利与基地损失两次各 9 项通过。测试直接调用建筑死亡入口推进，检查场景和两级目标、奖励、三个音频文件及结算结果。日志位于 %TEMP%/it-yr-win.log 和 it-yr-loss.log。人工整局、实听、冷读档和导出包仍待验证。
