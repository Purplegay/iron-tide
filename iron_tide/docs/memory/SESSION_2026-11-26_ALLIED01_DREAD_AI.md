# 盟军首关：四支无畏舰任务路线

接 `SESSION_2026-11-26_ALLIED01_ARMOR_AI.md`，用户要求继续补剩余部分。`ALL01UMD` 的 `085159EC` 四支 French 房无畏舰队 `09569A4C/0956959C/0956AEFC/0B4FFC8C`，原图脚本分别记录 287/294/109 炮击、194 炮击转 127/289 水路、292 炮击转 127/290 水路、109 炮击转 513/127 水路。过去把部分炮击航点当航行目的地，陆地航点被水域检查跳过。

`allied_first.gd` 以各队原始行序接炮击、移动和跳回指令，使用正式 ForceFirePoint、DMISL 飞行目标与实际运动；航点进度挂 ship.special，旧档无进度的舰从第一个命令开始。以观察到该炮击目标有发射才推进；原 `42,2` 未实现，炮击完成按观测到首发代理，循环沿原脚本索引但未验具体次数。尚未接后续 DX/DY、平民船以及整关房级经济/工厂 AI。

Godot 4.7.2 隐藏无头、隔离真实存档 2 副本：`tests/allied_first_playable.tscn -- --reported-slot2 --dread-orders` 25/25、`--cold-dread` 4/4、`--retake` 23/23，均 exit 0、stderr 空。KD 在原位出场，使用真实武器发往航点 194，转向 127 后实际移动超 100 世界单位；隔离 quick 冷读看到既有已完成炮击及水路目标，续行超 60 单位，不重复生成。前置过场夹具推进与跳过，未验证命中伤害或其余三舰全程，未自然新开局通关、有头或打包。证据 `.validation/allied01-playable/dread-{first,cold,retake}.{out,err}`。测试未写玩家原档。此前缺项继续见 `SESSION_2026-11-26_ALLIED01_FLEET_RETAKE.md` 与完成度复查。
