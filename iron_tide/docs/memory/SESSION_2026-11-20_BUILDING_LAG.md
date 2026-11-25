# 建筑多卡顿：首轮诊断
用户打包后反馈建筑多很卡，要求看能否优化。生产源码零修改，无候选合入。证据根仓库.validation/building-lag-20261120。

使用当前生产源码，Python312 tools/performance_soak.py。每场30秒，preserve-player，隔离用户目录，不动玩家游戏/存档。首次进程审计未发现外部Godot/IronTide，但未保存持续进程审计，因此以下不是干净性能验收；不是ABBA。

126建筑245单位yr_isleland slot2 fixture：building-profile诊断exit0无stderr/source-audit无漂移；采样cost仅为被采样调用耗时累计，不能当完整耗时或按父子相加。native-profile30.138墙钟33.885模拟秒，5539加载函数，2095执行玩法函数。Building._process10916次inclusive520.232ms，Building._draw3384次105.830ms，unit.physics108719次18762.398ms，Battle._draw_hp_overlay89次798.792ms。探针严重干扰帧数，只作来源定位，不能直接推算生产帧收益。

Release4.7.2 isolated desktop frame-only 1600x900：graphics-base mean26.112/P9550.590ms，1150帧。仅诊断副本Building._draw入口return（不改生产），graphics-hidden2 mean27.090/P9552.115，1109帧，未见减少。隐藏主体会改变由draw同步的炮塔/拾取等状态，非语义等价候选。

大型fixture core-five/slot1：212建筑373单位/5AI。large-base mean35.565/P9562.107ms，844帧；诊断副本Building._process直接return（恢复_draw正常）large-update-bound mean36.184/P9561.004，830帧。停止建筑更新改变生产/攻击/战况，因此只是消融诊断，不是严格上界或正确候选，不可推广。该场未见消除建筑更新带来明显整体改善。

不能据此否认用户真实场景建筑数量相关卡顿。现有fixture建筑数与单位数同时变，未证明建筑数量因果关系；缺当前玩家存档、镜头/大量己方建筑/墙体的控制变量测试、逐帧尖峰来源。目前热点主要为单位物理/交通/桥层/寻路，视觉overlay亦有开销。不要重复固定名单/空状态早退、depth微优化、已否决受损建筑重绘候选。下一步先用户当前存档与镜头，再隔离图形Release同输入测试；有外部游戏仅诊断，不宣称验收，不停用户游戏。

早期hidden-source复制缺icon.svg.import导致graphics-hidden启动前失败；补齐icon导入与tests链接后graphics-hidden2成功。所有正式运行exit0，无合入、无新包。交接结果：没有已证实收益的建筑优化。
