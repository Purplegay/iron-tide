# 鲍里斯空袭恢复：Steam 尤复二进制核对（2026-11-26）

原版依据：本机 `C:/Program Files (x86)/Steam/steamapps/common/Command & Conquer Red Alert II/gamemd.exe`，SHA-256 `3E81A61775D2745D1DABE397325EF663CD994FFC194DA4E998E3BF5D2D308600`。使用临时目录中的 iced-x86 对原版 PE `.text` 原始字节反汇编；此文件 `.text` RVA 与文件偏移一致。未修改或运行游戏进程。

- `AirstrikeClass::RemoveAircraft` 0x41DC80：解除飞机链表引用、递减 `[ecx+0x30]`；0x41DCED 比较剩余数量，数量不大于零时，0x41DCF2–0x41DCFE 将全局游戏帧 `[0xA8ED84]` 写入空袭对象 `[ecx+0x40]`，并清除 `[ecx+0x3C]`、`[ecx+0x3D]`。同类重置函数 0x41DD10 也写当前帧。
- 空袭对象检查函数 0x41D7E0：0x41D7F5/0x41D7FA 按精英状态选 `[esi+0x48]` 或 `[esi+0x44]` 的恢复刻数；0x41D7FD–0x41D810 在未出勤 `[esi+0x3C]==0` 时计算 `[esi+0x40] + 恢复刻数`，与当前游戏帧 `[0xA8ED84]` 比较。由此确认最后一架离场后并非立即充能完毕，而是从末机移除帧开始计恢复刻数。
- `data/yr_soviet.json` 从零售 `rulesmd.ini` 提取的 BORIS 值为普通 `AirstrikeRechargeTime=100`、精英 `EliteAirstrikeRechargeTime=50`，机型 BPLN，普通 2 架、精英 4 架。本工程 `scripts/units/soviet_specials.gd::advance_sortie_reload` 在最后一架离场后设置完整恢复时长，与上述起算语义一致；15 规则刻/模拟秒约为 6.67 秒、3.33 秒。工程另有训练倍率，须和原版基础值区分。

本次只核对原版二进制与本工程现有实现，不改生产代码或玩家存档，不声称零售游戏画面逐帧实测。旧交接 `SESSION_2026-11-25_BORIS_CD_AUDIT.md` 中“起算时刻未验证”已由上述二进制证据补充。边缘判定本身由 `SESSION_2026-11-26_BORIS_EDGE_RELOAD.md` 描述，不能将“到边离场”误解为“到边即冷却完毕”。
