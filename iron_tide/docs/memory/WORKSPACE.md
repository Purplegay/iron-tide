# 工作区与协作

## 已存用户约定

- 实际仓库C:/Users/admin/IronTide，Godot工程iron_tide/。聊天cwd即使是KFramework，也不套用其Unity/MCP、服务器协议或系统记忆目录。
- 用户选择保留Godot、独立实现机制，RA2/YR与扩展模式分开。
- 默认改工程、后台验证、报告版本与变化；明确要求打包时再出试玩包。历史某次提交／推送授权不能泛化。
- 尽量少截图，优先日志、源码、状态与断言；必要视觉证据最小化。后台测试不打开可见窗口，不操作玩家游戏和真实存档。
- 共享工作区可能有大量无关修改，测试应冻结源码并审计范围，不reset、清理或覆盖其他工作。
- 已有Bug修复交付偏好：每版docs/fixes/v<版本号>/README.md，同步版本索引、CHANGELOG和首页。这是已存约定，本次整理不补造历史交付。

来源：[工作区与启动交接](sources/memories/extensions/ad_hoc/notes/20261023-211241-iron-tide-handoff.md)；[修复版本文档约定](sources/memories/extensions/ad_hoc/notes/20261103-165312-irontide-fix-version-readmes.md)；[远征与HUD完整记忆](sources/memories_v2/extensions/ad_hoc/notes/2026-11-17-irontide-expedition-and-hud.md)。

## 项目入口

| 内容 | 入口 |
| --- | --- |
| 版本 | [project.godot](../../project.godot) |
| 源码／配置／测试 | iron_tide/scripts、data、tests |
| 更新历史 | [CHANGELOG](../../../docs/CHANGELOG.md) |
| 性能历史 | [PERFORMANCE](../../../tools/PERFORMANCE.md) |
| RA3适配 | [RA3_PORTING](../../../docs/RA3_PORTING.md) |
| 模型制作 | [MODEL_RENDERING](../../../docs/MODEL_RENDERING.md) |
| 玩家启动 | iron_tide/启动游戏.bat → launch_game.ps1 |

## RA3来源

所有RA3相关实现、补充、修复与调参先核对官方SDK／起义XML、XSD、继承和引用链。记录源文件、字段、原值及时间／距离／动画换算；逐项检查模型、动画、炮口、移动、武器、技能全周期、声音、生产、死亡及英雄变体。

官方起义XML为规则依据，Upheaval／社区重建只作交叉参考。用户明确自定义的改动另行标注；缺失SAGE CPU行为和Godot适配保留缺口，素材导入不等于完整复刻或用户视觉认可。

来源：[SDK权威约定](sources/memories/extensions/ad_hoc/notes/20261027-182926-iron-tide-ra3-sdk-authority.md)；[逐项XML补缺要求](sources/memories/extensions/ad_hoc/notes/20261028-164515-irontide-ra3-xml-completeness.md)。
