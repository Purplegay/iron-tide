# 飞碟开火时闪退

21:46、21:58、22:03 和 22:12 的 Windows Application Error 均指向发行运行时内偏移 0x2d583e3。22:12:53 的 PID 88628 与正式战场文件名一致。该局先有两次敌方 DiskLaser 对 HTNK 创建光束，最后一条是对 SHK 的 laser.created，随后日志截止。创建节点和渲染第一帧是两个时机，尚无原生栈。

BattleScreen 装配 battle_crash_trace，每局独立 user://battle-traces/*.jsonl。每秒记录部队、建筑、击杀、资金、选择和近期消息。开局、恢复、自动保存、退出和飞碟开火关键阶段立即 flush。后补命中特效、伤害和弹体分界。未调整武器机制。

21:55:35 的 quick.itsave 复制到独立项目用户目录，用同一发行 exe 加载，解除读档暂停。自然回放固定 24 FPS 有 16 次光束创建，目标全为 HTNK，2 次自动保存成功，最后有 battle.exit。另一轮单独补齐单位并指定 SHK，记录到 impact.end 和 damage.end，PID 77036 exit 0。两项均未重现玩家的原生异常。未验证汲取分支与可见第一帧。正式玩家日志、自然回放和定向回放分别保存在 .validation/quick-disc-20261125/player-crash.jsonl、replay.jsonl 和 targeted-shot.jsonl。
