# v0.26 · 重绘、特效、攻击表现与挂件轻量检查

按本次要求做共用入口检查与局部减负，不展开大规模重构或长局性能专项。版本进入 0.26；保留其他工作区未提交改动。

## 本版改动

1. **建筑重绘**：原先所有 Powered 建筑每帧请求整栋重绘，即使供电正常也一样。现在仅真实显示缺电角标时持续刷新，恢复供电补一次重绘清除角标。动画换帧、炮塔、开火、受损、选择、建造等各自刷新仍保留。
2. **特效材质**：RA2 发光 SHP 动画共用一个只读使用的加法混合材质，避免每次炮口火光／爆炸都创建相同资源。动画帧率、寿命、音效和销毁路径不变；需要逐实例参数的 ShaderMaterial 没有合并。
3. **挂件变换**：旋转／尺寸／偏移未变时复用局部变换；骨骼姿态继续同步，最终 Transform 未变时不重复赋值。编辑器调整任意轴、尺寸或偏移立即失效重算；动态骨骼 rest 仍实时读取。
4. **攻击尾迹**：一次绘制复用 world 查找和坐标逆矩阵，相邻线段共享端点视野结果；记录轨迹时复用本次类型判断。不缓存跨帧迷雾，避免出现或消失延迟；不修改命中、伤害、射速、飞行轨迹和攻击判定。

## 轻量检查覆盖

| 范围 | 检查入口及结论 |
|---|---|
| 单位／建筑重绘 | unit、building、grizzly_visual_refresh、attack_range_preview、attack_cooldown_indicator；保留动画、转向与状态即时刷新，修正供电建筑无效刷新。大组选区已有范围汇总。 |
| RA2 特效／素材 | ra2_fx、effects、ra2_art、vehicle_damage_particles、yr_death_fx；已有素材缓存、按帧动画、有限受损烟雾和死亡特效生命周期；本次合并发光材质。 |
| RA3 模型／粒子 | ra3_unit_model、ra3_future_particles、ra3_gunship_impact、ra3_crash_fx、ra3_tank_fx；已有部分 30 Hz 更新、屏外模型 viewport 停更及坠毁效果数量限制。复杂粒子与多 viewport 仍是密集场景的开销风险，本轮不重构。 |
| 攻击／弹道 | unit 搜敌已按 0.32 秒计时并错开初相位；检查 projectile、projectile_visual、projectile_tail；仅减少尾迹绘制重复工作，未改变战斗逻辑。 |
| 挂件 | cosmetic_anchor、unit_cosmetics、signature_mount；挂件接敌装饰查询已有 0.2 秒间隔；固定变换缓存生效，编辑与骨骼绑定继续保留。 |
| 音效缓存 | ra2_sfx 已有 256 条／16 MiB 缓存限制与播放节点回收；本轮没有改变声音数量和语音逻辑。 |

这是一轮共用链路轻量审查，不等于逐个兵种、每种技能和全部交战规模都做了实测。没有通过隐藏特效、缩短射程或降低攻击频率制造性能改善。

## 验证与实际证据

独立 `CodexIronTideValidation` 用户目录和 APPDATA；仅 headless 与 Win32 私有 desktop，不调用 SwitchDesktop，不占用前台，不操作玩家存档。

- light_visual_performance：82 项。
- weapon_trail：334 项；building_animation：704 项；grizzly_visual：21 项。
- 不可见图形环境：mount_rotation 33 项、mount_size 36 项、修改前后尾迹逐像素对照 4 项。
- 合计 **1214 项通过**。最终运行日志无 SCRIPT ERROR/ERROR。首轮隔离副本漏拷 icon.svg 的脚手问题已补齐并重新运行图形检查。
- 在正常供电专项中，电力分支 600 次检查产生 0 次多余重绘请求；断电、恢复、施工状态切换仍正确刷新。该数字仅指电力分支，不代表所有建筑重绘归零。
- 同一条 49 点、含迷雾遮挡的尾迹，普通／水花／烟雾绘制视野查询由 86 次降为 49 次；四类尾迹画面与修改前逐像素一致。不同遮挡分布的收益不同。
- 未做整场 FPS、P95 或长局基准，不承诺消除全部卡顿。用户实战观感仍为 `pending_user_visual_confirmation`。

证据：`C:/Users/admin/Temp/iron-v026-check-a`、`C:/Users/admin/Temp/iron-v026-graphics-final`；本轮修改前源码保存在 `C:/Users/admin/Temp/iron-v026-light-audit/before`。

## 关键代码

- `iron_tide/scripts/buildings/building.gd`：供电提示重绘失效判断。
- `iron_tide/scripts/core/ra2_fx.gd`：发光动画材质复用。
- `iron_tide/scripts/units/cosmetic_anchor.gd`：挂件局部变换缓存。
- `iron_tide/scripts/units/projectile_visual.gd`：尾迹坐标和可见性查询去重。
- `iron_tide/tests/light_visual_performance_regression.gd`：边界、回收与重复工作计数专项。

不需要重开养成存档；重启游戏加载新代码即可。本版未重新打包；Git 交付以仓库提交记录为准。
