# RA3 光照与阴影 · v0.5.7

## 原始依据

原实现为固定冷色环境光c1d2e5/0.65和一盏方向(-52,-35,0)/强度1.1白光；三种单位脚下均画固定椭圆，无法体现炮管、履带、机翼或骨骼变化。

本轮读取官方SDK `SAGEXML/System/LightingSettings.xml`、`Schemas/xsd/System/LightingSettings.xsd` 以及官方Uprising `Xml/System/LightingSettings.xml`。基础RA3和起义默认AFTERNOON三条配置一致：

| 光 | Ambient RGB | Diffuse RGB | LightPos (SAGE z向上) |
|---|---|---|---|
| Sun | .21961,.20392,.17255 | 1,1,1 | -.81,.38,-.45 |
| Accent1 | 0,0,0 | .23529,.23529,.47059 | .79,.62,0 |
| Accent2 | 0,0,0 | .11765,.11765,.07843 | .81,-.48,-.34 |

Schema明确Sun/Accent1/Accent2；OccludedLuminanceScale默认.5。官方 `Uprising/Shaders/Shadow.fx` 包含阴影贴图后处理及中心/十字邻域混合，说明原版是阴影图流程，不是脚下椭圆。本轮保留4份来源哈希于 `assets/ra3/lighting.json`，运行 `python -B tools/ra3_mirage/import_lighting.py` 可重建并验证版本一致。

## 本轮消费

- `ra3_lighting.gd`：三个方向灯、暖环境光；SAGE(x,y,z)转Godot(x,z,-y)。XML色值按线性颜色解释，转到Godot颜色输入。光照方向随地图相机角度转换，避免单位转身时太阳跟随单位转动。伪装树和残骸也使用此光照。
- `ra3_ground_shadow.gd`：复用原蒙皮Mesh和Skin，仅复制主材质网格到独立渲染层，不包含枪口/发光FX；以太阳方向投影到y=0平面。遮罩使用同一个World3D，摄像机分层，主模型纹理和鼠标命中不包含遮罩。
- 原模型搭建发生在进入场景前，不能直接查询Node3D.get_world_3d或使用私有viewport.world_3d的空属性；创建显式独占World3D，再共享给两台摄像机。原生模型摄像机层1，阴影层2。
- 384²遮罩捕获范围是模型摄像机的3倍，覆盖高车体及长炮管投影；平面三角面先合并为不透明白色遮罩，再在2D混合一次透明度，避免重叠累积变黑。源Mesh、Skin、骨骼路径共用，不每帧CPU读回或重新建网格。
- 飞行升高不把地面影子向上抬：由已有屏幕lift除以1.5像素/单位及cos(30°)换算高度，沿太阳方向计算地面偏移。柔化随高度增加、透明度下降。阴影绘制在父单位之后层级的后方，采用同一Iso绘制变换。
- 已有单位伪装透明度、迷雾可见性、装载隐藏继承到影子；30Hz捕获、离屏禁用，生命周期归单位；读档/死亡随单位释放。RA2预渲染图片保持原路径。

## 明确的Godot适配与剩余项

三盏灯的原数值已消费，但Godot PBR材质和色调响应不等于SAGE着色器。仍沿用已有法线/SPM/自发光解释，不宣称修齐全部材质参数。

平面投影并不是原版阴影图：暂不覆盖物体自遮挡、建筑接收影子、坡地/地形起伏、完整阴影级联、残骸逐块投影。当前阴影底色(.025,.035,.045)、基础透明度.36、五点柔化及高度浓度公式为Godot表现选择；OccludedLuminanceScale=.5被记录但不冒充直接等于透明度。伪装树当前沿用车体淡出影子，尚未另生成树叶alpha裁切影子。

未来坦克/炮艇已有开火点光保留；仍局限各自独占3D世界，不照亮邻车或2D地面。全地图武器照明、爆炸照亮建筑、HDR/Bloom、云影与昼夜/每地图光照需要后续独立接入。本轮没有添加这些特效。

## 验证

专项 `tests/ra3_lighting_regression.tscn` 必须真实渲染：检查原数值、三灯、实际阴影非空且不裁切、车体转向像素差异、Mesh/Skin共用、主图与阴影分层、隐藏恢复、飞行高度偏移/浓度、伪装淡出和RA2隔离。见VERIFICATION的运行位置；视觉结果仍为 **pending_user_visual_confirmation**。
