# IronTide 叠层显示约定（用户明确要求写入记忆）

用户要求：带叠层的天赋在脚底有可读的层数特效，各层颜色不同；后续同类机制一起遵守。实战与演示应一致，不能仅在文字描述里写层数。

当前实现入口：C:/Users/admin/IronTide/iron_tide/scripts/ui/talent_stack_indicator.gd。分段光环＋名称＋当前层/上限，第1～4层青/绿/金/紫，空段暗灰。已覆盖停火蓄电、辐射扩散、收割者协同瞄准主副目标、装配被动相位稳流；命中 Heat/Flux 同步颜色。

层数权威来自各机制的真实运行态：tesla_reserve_stacks、rad_growth_stacks、reaper_heat[target]、phase_time。只读展示，禁止表现层另行计时或改变伤害/存档。叠加、实际消耗、到期、起身、切换目标、死亡和装载须跟随真实规则；目标各自叠层不得相加或转移到新目标。演示可压缩时间但须读取当前配置，明确演示边界。计数不能只靠颜色，必须保留数字。避免全场扫描、每层粒子节点或额外每帧计时器，未来更多层数应限制绘制量但显示真实数字。

2026-11-05 v0.25.66：1591项无窗口逻辑断言通过；实际视觉仍 pending_user_visual_confirmation，不能记成玩家已验收。证据 C:/Users/admin/Temp/iron-stack-vfx-20261105-c/，版本记录 docs/fixes/v0.25.66/README.md。此条不授权弹窗测试或改动其他战斗规则。
