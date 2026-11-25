# RA3 残骸随机性对照 · v0.5.6.6

## v0.5.7.4 残骸仍聚拢的修补

用户截图的主要问题是分块虽独立，抛散量却不足。通过真实Future受击死亡入口、固定局部种子12345、自然等待2.6秒复现：旧大块水平移动约3～7模型单位，块宽约16～35；9块中仅2块超过各自宽度。此前随机性测试只证明运动不同，没有证明明显分离。落地时间截断同时把水平速度和自转直接清零。

官方来源仍为下表三份Collapse与DynamicsDraw/Dynamics schema，原几何、骨质量、Explodiness、FlingPerturbation、Spinniness及寿命未改。以下是修补的**Godot表现适配**，不冒称恢复了SAGE的力、惯性或接触求解：

- 径向分量从归一化方向改为原始模型平面偏移量 × Explodiness ×0.5；随机扰动消费完整FlingPerturbation，不再乘0.35。质量权重仍是适配，但上限由2收至1，避免小碎片额外成倍飞远。独立旋转／独立随机源保留。
- 原解析飞行时长、重力24保持；落地后按exp(-4t)衰减水平速度和旋转，竖直位置继续使用旋转AABB托地及原下沉。该阻尼不是原ContactTag摩擦。
- 按实际分块角点扩展捕获范围，绘制矩形与正交相机尺寸同步，原1.5像素/模型单位比例保持。纹理分辨率768起、128一档、上限1536，只增不减；24残骸上限、离屏停止捕获保持。无碎块互碰撞或自动切割。

新增`ra3_wreck_scatter_regression`通过真实致死伤害创建唯一残骸，等待真实回调，确认原演员回收、多数块移动超过自身宽度、地面惯性连续，并保存战场与独立残骸截图。修补前5项失败2项；最终5项全通过。共享实现同步影响幻影／炮艇，已回归原随机／完整表面、native、expansion及真实死亡清理。输出根`refs/ra3-expansion/wreck-scatter/`，最终源码结果在`final*`目录；`before`为原复现，`after`为中间调试，不能混作最终。最终视觉状态仍`pending_user_visual_confirmation`。

下文为v0.5.6.6历史实现，力度与落地部分以本节为准。

## v0.5.7.2 静止靶标尸体清理补充

用户反馈残骸不消失，实际复现为GM静止步兵死亡动画冻结：生成时禁用物理回调，死亡回收也依赖此回调；另有gm_stationary提前return拦截。现仅冻结存活行为，Die1死亡动画恢复回调。新 `gm_death_cleanup_regression` 从真实GM/受击入口等待约9.6秒，证明原单位回收及三个RA3独立碎块5～9秒渐隐、最终释放。没有缩短/延长官方残骸寿命；旧手动age断言不能代替这次实际调度验证。证据见VERIFICATION的v0.5.7.2。

## 根因与来源

旧 `ra3_wreck.gd` 虽然已载入COL真实碎块，却按中心外向量和循环索引奇偶固定速度、转轴；所有碎块运动在1秒截断，Lifetime取固定4.5秒。每次死亡表现相同，没有消费SDK的随机字段。

官方 `refs/ea-modding-support/Uprising/Schemas/Modules/DynamicsDraw.xsd` 定义：Explodiness为由原点向外的力，FlingPerturbation为逐骨添加的随机向量幅度。`Schemas/Includes/Dynamics.xsd` 定义Spinniness为抛散时额外随机角动量。它们支持随机运动，**不表示实时随机切割网格或随机删减碎块**；未指定体积的骨骼依附父骨。

| 官方Collapse | 刚体块数 | Explodiness | FlingPerturbation | 每块Spinniness |
|---|---:|---:|---:|---:|
| Allied/Props/AlliedAntiVehicleVehicleTech3_Collapse.xml | 11 | 8 | 15 | 5 |
| EP1/Allied/Props/AlliedFutureTank_Collapse.xml | 9 | 4 | 15 | 3 |
| EP1/Allied/Props/AlliedGunshipAircraft_Collapse.xml | 10 | 4 | 15 | 3 |

以上路径相对官方Uprising/Xml。三者LifetimeUpdate均为4～5秒；Draw维持5秒后4秒淡出，SinkDelay=1s、SinkRate=1.5保持原有配置。幻影基础RA3 SDK与起义的DynamicsDraw属性、BoneVolumes属性逐项一致。

`tools/ra3_mirage/import_wreck_dynamics.py` 导出 `iron_tide/assets/ra3/wreck_dynamics.json`，保存6份官方源文件SHA256及各骨质量/旋转/ContactTag。未来坦克和炮艇沿用既有SAGE Poid名称哈希，与全部COL表面逐项核对；同一块的身体与履带表面仍共用一个运动节点。运行 `python -B tools/ra3_mirage/import_wreck_dynamics.py` 可重建，不重导其它媒体。

## 实现及适配边界

- 每个残骸独立RandomNumberGenerator，生成逐块均匀球面方向和转轴；不调用战斗全局随机数。每实例采样4～5秒后加1秒开始沉降；显示仍9秒清理。
- 当前Godot力度换算：质量权重clamp(800/mass,0.5,2)，径向强度乘0.5，随机扰动乘0.35，随机旋转乘0.2。原有速度继承乘0.05与向上基础速度9仍为适配；这些换算不是SDK常量。
- Godot重力24单位/秒²，按每块高度/初速解飞行时间，落地后停止运动；旋转AABB托住几何，随后按原配置沉降。时间解析式不因帧率改变随机落点。捕获区域扩大一倍、纹理边长同步扩大一倍，保持1.5像素/模型单位。
- 没有引入路径障碍、伤害、存档字段；24个残骸上限及读档清理保持。暂停由战斗场景继承，离开视野关闭渲染。
- **未复刻**SAGE惯性张量、Box接触/反弹/摩擦、ContactTag音效/粒子、完整OCL抛射。原幻影Die_OCL含INHERIT_VELOCITY、VelocityScale=20、ForceMagnitude=1～2、Pitch=90→75度；不能直接套用为Godot像素/秒，也不能擅自交换倒序区间。随机向量分布和换算仍是明确的Godot适配，未取得SAGE逐帧实机对照。
- 炮艇从飞行高度坠落的完整过程、Collapse粒子和地表焦痕也不属于本次已完成项。

## 验证与交接

新增 `tests/ra3_wreck_random_regression.tscn` 实际渲染专项107项：源参数、质量映射、固定种子可重复/不同种子不同、零字段关闭随机分量、全局随机序列不受影响、三单位真实spawn/表面完整、离地/落地几何、捕获裁切、原生命周期。原native93项另覆盖真实死亡去重、RA2隔离、超时空抹除、上限24和读档清理；expansion63项覆盖共用模型消费者。全部通过，运行根见VERIFICATION。

已查看两次幻影死亡0.6秒截图及炮艇落地截图，运动形态不同，表面完整。游戏实机观感仍为 **pending_user_visual_confirmation**；用户确认前不当作SAGE物理完整验收。
