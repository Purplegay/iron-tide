# 英雄第十六批：雷铸过载保险 Lv.1～2

v0.29.27，2026-11-18。开放反寄生放电、电能回收及购买、状态、保存、远征和逐级演示。完整英雄功能链仍为 7/8；雷铸防御 Lv.3～5、新英雄外观、全量核对及正常皮肤定价继续，总目标 active。未改已叫停的旧皮肤外形。

## 接通行为

- **Lv.1 反寄生放电**：真实恐怖机器人成功寄生时开始两秒计时，期间保留正常寄生伤害；到时存活且未冻结／EMP、未装载才清除并摧毁当前寄生体。控制结束后可以完成已经准备好的放电，实际放电后间隔三十秒。间隔内再被寄生仍正常受伤，不刷新冷却；准备与间隔都满足才再次放电。外部维修清除或寄生体离开不白耗反制，转属清除旧待处理事件。
- **Lv.2 电能回收**：敌方普通电击本次护盾吸收与实际生命损失之和的 20%，在伤害结算且存活后加入独立回收盾；总量不超过最大生命 15%，有效回收刷新四秒。原生 `tesla` 与通用 `electric` 类型均接通，原生磁暴步兵开火已验证。旧回收盾可吸收下一击；新生成的盾不能挡住产生它的那一击。友伤、自伤、追加／装备副击、转移伤害、无实际损失和致命伤不产生回收盾。
- 回收盾与线圈护套／夺取盾独立计时，正常消耗后溢出扣生命，不治疗生命、不触发旧坦克英雄破盾爆炸。状态栏显示准备、放电间隔与回收盾剩余量；场景绘制放电脉冲和独立护盾环。
- 防御等级使用开局冻结档案。Lv.1／Lv.2 通过实际 UI 按 40／120 战略核心购买并保存，失败回滚；Lv.3～5 未开放，不扣钱。修正防御说明里“指挥供电尚未开放”的过时文案，指挥完整链保留。
- 二进制快照及实际远征检查点保存寄生体引用、两秒准备剩余时间、回收盾量与寿命；恢复后继续原计时，反制只结算一次。三十四秒反寄生演示覆盖完整三十秒冷却；八秒回收演示说明受击后加盾及下一击的吸收／再回收过程。

## 验证

结果：`C:/Users/admin/IronTide/.validation/leizhu-defense-20261118/summary.json`，**2405 项，0 失败，最终专项日志无 SCRIPT ERROR / ERROR；GPU 47 项，0 截图**。

| 专项 | 检查数 |
| --- | ---: |
| leizhu_defense_regression | 62 |
| leizhu_defense_demo_regression（GPU） | 22 |
| leizhu_demo_regression（GPU） | 25 |
| leizhu_base_regression | 111 |
| leizhu_command_regression | 79 |
| leizhu_station_regression | 68 |
| leizhu_cards_regression | 206 |
| shield_damage_paths_regression | 254 |
| final_damage_limit_regression | 124 |
| progression_expansion_2_drone_regression | 145 |
| soviet_advanced_regression | 86 |
| hero_talent_cost_regression | 245 |
| progression_expansion_2_regression | 978 |

新专项走原生寄生接触、真实英雄物理更新、原生磁暴步兵开火、Unit.receive_hit 护甲／护盾／生命结算、实际 UI 购买与失败磁盘回滚、二进制快照和远征检查点。部分控制／冷却边界直接推进已接入 tick；寄生扣血断言明确关闭测试英雄自愈，以隔离反制是否错误免伤／回血，产品自愈规则未改。初版发现原生电击类型不同、转属旧计时及自愈干扰测试的问题，已修正并重新验证。只将最新 result.json 与同目录 godot.log 计作通过，开发中间失败不冒充通过。

Godot 4.7.2，验证工程链接当前 IronTide 脚本与测试；每次使用独立 APPDATA／LOCALAPPDATA，未连接服务、数据库或网络协议。GPU 使用未激活私有桌面，输入桌面前后均为 Default；两次最终 GPU 正常退出，回归后无本批验证进程，证据见 post-run-audit.json。没有截图、用户可见验证窗口、打包、提交或推送。

视觉观感与自然对局平衡为 **pending_user_visual_confirmation**。本批不关闭旧学院／犬扑缺口或已暂停的六家 33ms 性能目标；雷铸冻结缓行、分流及停堆尚未交付。
