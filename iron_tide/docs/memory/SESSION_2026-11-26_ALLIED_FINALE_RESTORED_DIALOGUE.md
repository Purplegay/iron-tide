# 终关补接零售录音和废案语音

续读 ARMOR_LANDING、MARK_DRAW_SUPERWEAPON、迁移技能的废案取证门槛。`data/waves.json` 当前名《脑死》无试玩尾缀，本轮没重复修改。现成 `data/ra2/allied_finale_voice_extras.json` 和 `tools/allied_voice_extras.mjs` 保存 Steam `langmd.mix > audiomd.mix` 源和哈希。

`allied_finale.gd` 在终关后段使用真实 AudioStreamPlayer/HUD 电台。原图 `0F22154C` / `0C028AFC` 的现成录音 xa7ev03 / xa7ev05，按南极基地展开及建好盟军战车工厂补播，保留原图全场计时门槛的近似；不附带未迁移的油井抢占链。通用超武广播已播警告，不重复接同一检测音。xa7yu01（CSF/EVA 英文：So you finally located me? Let us end this.）和 xa7ev01（EvaBoomerThreat）没有查到 ALL07SMD 动作 21 直接调用，采用项目补接：真实己方单位抵达已可见控制器附近时播放尤里录音与雷达提示；可见雷鸣潜艇首次侦测则播伊娃警告并提示雷达。二者不会因为自动超武广播或未探测的潜艇提前触发，不改变迷雾、兵力或胜负。语音键仅一次，由既有 allied_state 保存；中文除尤里句是译文外为简报要点，未逐句精听。xa7ev02、xa7ev06 保留候选，未接。

Godot 4.7.2 隐藏无头隔离真实菜单 52/52，独立进程雷达冷读 5/5，stderr 空，`.validation/finale-extra-dialogue/`。主回归修正正在使用的独立战场绘制层测试入口；新增断言超武广播不提前触发、夹具将己方单位放到目标附近后实际音频节点播放、重复轮询不重播。未单测潜艇实际声呐接敌与录音、语音已播节点独立冷读、有头试听或发行，未修改玩家档。