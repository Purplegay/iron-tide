# Iron Tide v0.5.0.3 修复说明

2026-10-28

- 修正先锋武装炮艇使用悬停逻辑：待机和攻击持续盘旋，按起义 CirclingRadius=290、CirclingSpeed=80% 使用 435 地图半径及 144/秒巡航；转场最高速度保持 180/秒。
- 移动指令转入目的地区域的等待圈；停止取消任务后在附近继续飞行，两种武器均可在盘旋时攻击。保存盘旋中心，读档不重新定位；地图边缘将等待圈中心内移以容纳航线。只影响 R3HARBINGER。
- 轨迹为基于原参数的连续转向适配，并非完整 GunshipJetAIStateMachine CPU 复刻；没有把源 CirclesForAttack=false 擅自改成 true。三组回归 888 项通过，飞行手感待用户确认。

[全部修复版本](../README.md)
