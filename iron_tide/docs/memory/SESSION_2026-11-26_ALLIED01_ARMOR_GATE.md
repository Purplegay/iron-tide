# 美国首关：穿越后的装甲进攻和谭雅入场门槛

接 `SESSION_2026-11-26_ALLIED01_COMPLETENESS_RECHECK.md`。用户要求开始补，并把漏验经验写进战役迁移技能。此前存档 2 自然直达谭雅的报告已被新阶段顺序取代，不作为本版自然通关证据。

零售 `ALL01UMD`（SHA 见首关原图交接）`Start_Sounds2 04C19E5C` 在时代切换链中启用 Easy `087C0E4C`、Med `087C0F3C`、Hard `087C0D5C`；事件 13 原始参数分别 90/100/30。两队 `0925E45C`（2 HTNK、1 TTNK，脚本先往航点 14）、`0925FDEC`（3 HTNK，先往 421）从 RM 出场。清除门槛 `Apocs_Gone 0AC8355C` 原版检查房号 13 Special 和 15 Soviet2House，随后启用 `Enter_Tanya 0AC85F3C`，原始延时 5。

`scripts/world/allied_first.gd` 移除充能第 5 秒提前出兵。穿越后才按关卡难度开始计时，两队带身份分别向航点 14/421 攻击移动，HUD 先显示迎击及倒计时，再显示剩余装甲；必须清掉两队，等 5 秒才出现谭雅并显示恶魔岛目标。穿越途中冷读不提前派人；旧存档 2 从已有供电继续。已到旧阶段 4 且无 awaiting_tanya 的档沿用原进度。代码以项目模拟秒映射原字段，不宣称已测得零售实际计时；出场暂用境内 41 替代图外 RM，攻击移动是脚本命令近似。装甲队清除是本批门槛代理，不是完整两房清除语义。A01_P02E 仍随谭雅串播，未移植其原独立触发链；夺厂、完整时代场景、入场路线、桥坡、敌房经济仍排队。

Godot 4.7.2 隐藏无头、隔离 APPDATA：`tests/allied_first_playable.tscn -- --reported-slot2 --swim` 24/24，`--reported-slot2 --carriers` 22/22，`--cold-crossing` 4/4，新出击 25/25，均 exit 0、stderr 空。证据 `.validation/allied01-playable/defense-*.{out,err}`。实际旧存档副本，无需重占厂；用夹具推进计时、将新增两队血量置零验证清除门槛，谭雅实际跨海进入 C4 逻辑。仅核对三档字段及存档本身所属难度的运行触发前后，未逐档自然交火、未验证图外通行/两队到达、未验航母实杀，未图形、未打包。玩家原存档 SHA 前后均为 `57213705CE674EEBC6DE9F8D77E10402E856D8F767ABD4BD3EA5BD543F442E0B`。

仓库版 `docs/skills/yr-campaign-porting/SKILL.md` 与已安装 `yr-campaign-porting` 同步增加整关硬门槛：新开局自然验证、真实触发门槛、换场清单、替代路线实杀、首帧迷雾和音视频解锁、冷读房色。顺带修正终关 MAP 名为 `ALL07SMD`。下批优先真正接旧金山逐厂争夺和时代对象差异；达到真正独立房号后将装甲门槛替换为原图双房检查。
