# IronTide 全单位 Buff / 叠层显示（用户明确要求统一记忆，2026-11-12）

- C:\Users\admin\IronTide：所有单位的持续 Buff、Debuff、倒计时、叠层统一显示；单位上用小状态图标，状态栏用小格，悬停查看名称、说明、剩余时间、层数/上限。收起单位菜单仍显示状态；避免头顶文字堆叠。
- 主/副目标的叠层分开；显示层只读，不推进/重置计时或修改战斗状态；多选显示代表单位的状态，不跨单位合并。遵守迷雾、死亡、装载和敌方精确信息边界。
- 长期约定和入口已集中到 C:\Users\admin\IronTide\docs\UNIT_STATUS.md。主链：Unit.buff_entries → ui/unit_status.gd → 世界 HUD / ui/status_chip.gd / 被动详情。扩展状态必须有稳定唯一 id，不能共用 kind=progression 作为 HUD 字典键。
- 继续尽量少截图，优先隔离 headless 与实际布局数据；视觉观感需用户确认。
- 已实现；81 种单位及收割者部署形态专项 431 项、四分辨率 HUD 608 项通过。证据 C:\Users\admin\IronTide\.validation\unit-status-final-layout-20261112\。世界标志与 HUD 小格、悬停提示、独立叠层、到期移除、折叠菜单和横向溢出均有断言；无截图，视觉确认仍待用户。
