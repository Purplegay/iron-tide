# v0.5.13 单位选中描边

用户要求选中单位具有RA3式模型描边。此功能是Godot独立表现适配，不改变选中对象、命中、攻击范围、逻辑位置或战斗状态。

## 原版依据

- `refs/ra3-sdk/unpacked/Schemas/xsd/Includes/OutlineDrawType.xsd`：NONE、SELECTED、HOVER_SELECT、HOVER_ATTACK是不同状态，本次仅接SELECTED。
- 同目录`RenderScene.xsd`：UnitOutlineSelected、TransparentOutlineSelected和StructureOutlineSelected分列，不能把整张HUD／阴影当单位轮廓。本次范围为Unit，建筑仍保留原表现。
- `Schemas/xsd/System/UnitAISettings.xsd`的SelectionFlashSaturationFactor=0.5、SelectionFlashHouseColor=false描述选中闪色，不等同于描边颜色或宽度。没有据此推导未公开的SAGE描边shader。浅绿色和1.5视口像素是本项目适配值。

## 实现与交接

`unit_selection_outline.gd`在Unit._draw的本体分支开始收集、结束关闭收集。RA2Art.draw_sprite、ShpDetail.draw向它提交实际使用的纹理、裁切区域、绘制矩形和透明度；SHP高清页、体素高清图集与独立炮塔共用真实绘制几何。直接绘制的间谍／幻影伪装以及Ra3UnitModel／Ra3ExpansionModel的ViewportTexture也接到该入口。采矿、武器、血条和选择圈处于收集范围外，阴影使用独立绘制路径不参与。

每个已选单位只维护当前本体所需图层，专用selection_outline.gdshader根据alpha膨胀边缘；采样在当前源帧内截断，半像素边界避免相邻图集污染。轮廓在原单位下方绘制，原模型覆盖车体与炮塔相接处；不覆盖或替换原house_remap、C4、冰冻等材质。线宽按相机变换换算，跟随Iso与受击摇晃；不做每帧CPU纹理读回、不为RA2创建额外Viewport。取消选择和死亡立即隐藏并释放图层引用，旧姿态多余图层清空；隐藏和登载跟随原可见性。动态RA3纹理不缓存成静态贴图。

尚未给没有SHP/VXL/RA3纹理的早期程序化占位图形追加轮廓；它们仍沿用原选择环。未新增建筑、悬停敌人或攻击目标描边。RA3视口中已有透明附属效果使用alpha门槛过滤弱光，具体实机边缘和多单位重叠观感仍需视觉确认，未宣称完全复刻SAGE深度描边。

## 验证

Windows/Godot4.7.2，串行headless隔离副本，每轮独立custom_user_dir；服务／端口／数据库none。未启动可见游戏窗口，未修改正式存档或停止用户游戏。

- selection_outline_regression：46项通过，含真实Unit车体＋炮塔、SHP高清绘制回调、选中／悬停区分、0.5/1/2/4倍缩放、透明度、收集边界、图层复用、摇晃、取消选择、隐藏／登载／死亡清理、RA3动态纹理参数。
- selection_regression：178项通过，原点选／框选行为保留。
- unit_art_regression：926项通过。旧测试假设尸体统一0.7秒回收，与v0.5.8已接入完整原死亡序列的契约冲突；改为原Die1帧数/13秒，并验证到期前不截断、到期后必须释放。未改死亡代码、未移除回收断言。

合计1150项后台断言，零SCRIPT ERROR/ERROR。首轮发现Godot shader编译器不接受将内置TEXTURE作为自定义函数采样器传参，改为专用silhouette_texture uniform后通过。报告位于`C:/Users/admin/Temp/iron-sidebar-20261028/`下：`selection_outline_regression-1793251423991`、`selection_regression-1793251296994`、`unit_art_regression-1793251379904`。导入检查为`import-1793251038801`，最终shader已随后续专项重新加载编译。

这些证明脚本／shader编译、状态及绘制参数，不替代GPU运行截图或使用者观感。状态：**pending_user_visual_confirmation**。未提交、推送或打包。
