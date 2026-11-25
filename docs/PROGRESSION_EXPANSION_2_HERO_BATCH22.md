# 英雄第二十二批：游隼飞行与返修状态表现

2026-11-18，v0.29.33。分批接入实际战斗表现，状态来自已有游隼规则，没有改变战斗数值、维护等待、返修时间或机场占位。完整极昼巡航32向机身素材仍未齐，本批继续使用原生ORCA机身，不能视为新皮肤完成；总目标active，表现为 `pending_user_visual_confirmation`。

## 本批变化

- 悬停双喷流随真实高度收束；接近地面时三处起落支架展开，起飞时随高度收回。不新增飞行命令或状态计时。
- 维护落地停喷流；真实无伤窗口满3秒且仍缺血时显示绿色修复亮点。受击重置窗口后亮点消失，满血不再显示回血亮点。
- 致命迫降立即关闭喷流、降低机身亮度，并用两个循环烟团标识损坏；即使已转换为1000%满耐久机体仍显示。实际工程师维修进度大于0时显示焊接亮点。
- 恢复后损坏着色、烟团与焊接退出，重新爬升时喷流恢复、支架收回。视觉模块自身不执行修复，180秒和工程师5秒规则仍由原Service负责。
- 英雄晋升和存档恢复安装视觉模块；普通入侵者不安装。养成展示只安装预览身份及装饰时钟，无生产、晋升或存档写入；暂停冻结装饰时钟。

实现：`scripts/units/peregrine_visual.gd`；入口为 `peregrine.gd` 的restore、Unit绘制与时钟、HeroProgression和UnitShowcase。效果直接绘制，未新增粒子节点或动态场景节点。此事实不等于整局性能达标。

## 当前证据

`.validation/peregrine-visual-20261118/summary.json`：4个专项337项通过、0失败，其中GPU133项；0截图、0可见验证窗口。

| 专项 | 检查数 | 范围 |
| --- | ---: | --- |
| peregrine_visual_regression | 27 | 四个朝向实际GPU喷流差异、起落高度、静默回血窗口、迫降满耐久烟雾、恢复、快照、预览暂停与档案不变、1000次装饰更新不增加节点或修改战斗状态 |
| peregrine_service_regression | 100 | 维护、迫降、工程师、摧毁、真实时钟、存档与远征等既有规则 |
| peregrine_base_regression | 104 | 真实生产赠送、普通机位隔离、悬停、自动补弹、原生开火、保存和模式边界 |
| peregrine_defense_demo_regression | 106 | 既有六节点演示时间轴、真实诱饵／抗扰／维护／迫降及恢复绘制 |

GPU专项通过未激活的私有桌面执行，输入桌面前后均Default。Godot4.7.2、GL Compatibility；验证工程scripts/tests/assets指向当前IronTide源码，每次独立APPDATA/LOCALAPPDATA。服务、DB、网络均none；结束后检查本批Godot/Python进程，见post-run-audit.json。无打包、提交或推送。

复验入口为本批缓存目录headless.py `<scene>`、gpu.py `<output-name> <scene>`。长期测试源码位于 `iron_tide/tests/peregrine_visual_regression.gd/.tscn`，其余使用现有专项。没有把简单的渲染成功当作画面质量验收；细节、位置和动态观感仍需使用者实际观察。本批也未宣称完成新机身、全量要求审计、自然对局平衡或整体性能目标。
