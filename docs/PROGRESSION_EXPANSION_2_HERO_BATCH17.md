# 英雄第十七批：雷铸绝缘缓行

v0.29.28，2026-11-18。防御 Lv.3 开放，完整链仍为 7/8；防御 Lv.4～5、新英雄外观、全量说明／演示核对与正常皮肤定价继续，目标 active。

## 行为与实现边界

持续时空光束冻结期间，雷铸可以接受普通移动命令、原生路径与阵型指令，以当前正常移速的 50% 移动。寻路、转向、落点和碰撞仍使用原生控制器；保留冻结状态与双方引用，不能开火或施法。没有修改 AlliedAbilities.frozen 或原生 channel，擦除继续按原速推进；停留／被障碍阻挡仍会被完整擦除，走出合法武器维持距离才由原生通道释放，之后恢复正常速度。

该例外只给防御 Lv.3 及以上雷铸的持续维持型冻结，不给普通单位、低等级、经典模式或只有计时冻结的状态。EMP、装载、维修及停堆仍阻止移动。供电、反寄生和其它冻结限制没有被移除。停堆是预留状态接口，Lv.5 尚未开放。

养成 UI 按既有 240 核心购买第三级，四个已实现节点可预览，Lv.4～5 仍禁止购买。实战详情改为雷铸真实指挥／防御文案，说明半速移动例外与不能开火／施法、仍会被擦除；新增十二秒逐级演示。二进制快照和远征检查点保留冻结双方引用、擦除进度、移动目标及开局等级。

## 验证

`C:/Users/admin/IronTide/.validation/leizhu-insulation-20261118/summary.json`：**1936 项通过，目标专项 0 失败，GPU 61 项，0 截图**。下表最终日志无 SCRIPT ERROR / ERROR。

| 专项 | 检查数 |
| --- | ---: |
| leizhu_insulation_regression | 51 |
| leizhu_insulation_demo_regression（GPU） | 14 |
| leizhu_defense_demo_regression（GPU） | 22 |
| leizhu_demo_regression（GPU） | 25 |
| allied_abilities_regression | 230 |
| leizhu_defense_regression | 63 |
| movement_order_regression | 34 |
| leizhu_station_regression | 68 |
| leizhu_cards_regression | 206 |
| hero_talent_cost_regression | 245 |
| progression_expansion_2_regression | 978 |

专项通过实际原生时空武器、英雄物理更新、原生开火／W 拒绝、实体障碍碰撞、真实移动指令分配和路径、原生擦除完成／离距释放、实际购买、二进制快照和远征检查点。半速断言比较真实位移与原移速，释放后再次比较全速位移。为隔离移动时长，逃脱场景使用高血量测试夹具，站定擦除另用正常生命与原生完成阈值。远征测试在新生成敌人后调用真实 fog.rebuild 发布视野，再检查合法光束续接，没有绕过可见性门禁。

**另有未通过的旧阵型专项，未计入上述通过数。** `formation_gesture_regression` 66 检查中 6 项失败：两种模式的单坦克出发／到达朝向，以及扩展模式两次预览模型来源。使用隔离验证目录复制该专项，并仅将 formation_gesture.available 恢复为本批前的冻结筛选条件，在同一环境重跑后，6 项名称、失败数与详细数值完全相同。对照见 formation-comparison.json 和 formation-baseline/；这证明这些失败不由本批的英雄移动例外引入，不证明旧阵型问题已解决。原测试与断言保留，未删改制造通过。

初次脚手的 Ability 构造调用及远征视野未发布问题已修正重跑；开发中间失败不计通过。Godot 4.7.2；验证工程链接当前源码，每次独立 APPDATA／LOCALAPPDATA；旧筛选对照仅在验证工程 validation_only 下，不修改当前产品源码。无服务、数据库或网络协议。GPU 私有桌面未激活、输入桌面前后均 Default；三次最终 GPU 正常退出，回归后无本批验证进程。审计见 post-run-audit.json。没有截图、用户可见游戏窗口、打包、提交或推送。

视觉和自然对局平衡 **pending_user_visual_confirmation**。本批不关闭旧学院／犬扑、上述阵型缺口或暂停的六家 33ms 性能目标。总核对还需修正其他三英雄在 battle_effect_details 中的高阶说明分支，详见协作记录。
