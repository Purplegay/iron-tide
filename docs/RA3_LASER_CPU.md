# RA3 幻影光束：CPU 宽度与渐隐核对

2026-10-27，v0.3.10.1。本节替代旧交接里“CPU未确认、宽度乘0.5、末尾0.3/0.1秒smoothstep”的结论。表现仍为 `pending_user_visual_confirmation`。

## 原始依据

- Steam《起义》`Data/ra3ep1_1.1.game`，SHA256 `b1da83efd229570bab9de3a14e48b2d1e6128e302bd52384858fa8a413ae330b`，PE32，image base `0x400000`。读取文件，不启动、修改或注入原游戏。
- 官方SDK单位/折射节点XML、Weapon.xml、LaserDraw.xsd：主/折射宽度25/5，寿命1.5/0.5秒，FadeInTime/FadeOutTime均默认0。
- [EA Laser.fx](https://github.com/electronicarts/CnC_Modding_Support/blob/3aad8e412961ab543192ae70f8503dc8e178e095/Red%20Alert%203/Shaders/Laser.fx)：RGBA相乘，RGB乘ColorEmissive，alpha乘顶点透明度，SRCALPHA+ONE；U Clamp、V Wrap、Linear。
- 本机Laser.fxo SHA256 `9aba52a55eff34d0351300e6edf6e40110c8698a54d5946964804778ec5bc648`，两份实际像素程序没有gamma幂运算，不能仅凭公开HLSL的条件分支再加pow。普通光束PNG的alpha全为255，自然衰减主要来自RGB乘积；仍保留完整RGBA算术。

## CPU 调用与公式

以下地址仅适用于上述EXE。

| 地址 | 核对行为 |
| --- | --- |
| `0x79d930` | LaserState构造，`state+0x7c`宽度倍率初始1 |
| `0x7fe05c`、`0x7fe18e..0x7fe1bb` | 激活LaserId；写入默认1或显式武器倍率，不是按age计算的尾部曲线 |
| `0x7ce4e0`、`0x7f4be0` | 写结束逻辑帧、按结束帧停用并更新端点；普通LaserState更新没有逐帧缩窄 |
| `0x8acaf0` | 取状态端点、宽度倍率和结束时间；结束时间换算含`endFrame+1` |
| `0x8b0130` | `instance.width = LaserDraw.LaserWidth * state.widthScale` |
| `0x5f3300` | 创建实例，记录渲染时间、UV tile/scroll和FadeIn/Out |
| `0x5fed9b..0x5fee29` | 线性透明度包络 |
| `0x5fee29..0x5fef21` | 按创建以来的时间生成两层UV |
| `0x5fef21..0x5ff428` | 相机朝向、叉乘半宽和4个顶点 |

```text
age = now - created
opacity = fadeIn > 0 ? clamp(age/fadeIn, 0, 1) : 1
if fadeOut > 0 and endTime != -1:
    opacity *= clamp((endTime-now)/fadeOut, 0, 1)

direction = end-start
if length_squared(direction) > 0.0001: normalize(direction)
view = normalize(cameraPosition - (start+end)/2)
halfWidth = cross(direction, view) * width * 0.5
# 不再次归一化叉乘：接近视线方向的光束投影会变窄。

vertices = [start+halfWidth, start-halfWidth, end+halfWidth, end-halfWidth]
baseUV = [(0,1), (1,1), (0,0), (1,0)]
uv0 = baseUV + age*(0.2,0.3)
uv1 = baseUV - age*(0.2,0.3)
```

幻影零包络时CPU opacity有效期内为1。两层RGB亮部沿U反向分开，乘积逐渐变暗/变窄；Clamp防止越界亮部绕回。不能把“没有CPU FadeOut”理解为没有渐隐，也不应额外叠加猜测的smoothstep尾部。

## 游戏接入与边界

`ra3_weapon_fx.gd`采用上述包络/叉乘；25/5源宽度乘模型统一的1.5世界比例，得到37.5/7.5的未投影几何宽度，实际亮部还受方向和纹理影响。删除旧0.5屏幕系数及尾部配置，修正起点V=1/终点V=0。`ra3_prism.gdshader`恢复U Clamp/V Wrap、线性过滤和RGBA乘法，移除合成边缘遮罩。

本工程是正交2D地图：视向量由Iso.K转换，目标深度来自地面坐标，高度反算以保持现有炮口/命中像素；不是原游戏透视相机的完整复刻。原生结束帧有一帧边界，本次保留现有Godot每次发射1.5/0.5秒生命周期，不改变战斗时钟、伤害、英雄周期或存档。死亡端点保留和迷雾规则不变。折射只持续0.5秒，不再人为添加最后0.1秒尾部。

## 验证与复现

`audit_laser_cpu.py`先校验EXE完整哈希，再把无外部调用的原始`0x5fed9b..0x5ff428`算术片段放入独立Windows x86进程运行。仅增加调用包装和只读常量地址重定位，不加载完整游戏或连接游戏进程。机器码只保存在忽略的本地证据目录，不提交或发布。依赖Python标准库及Windows内置32位PowerShell/C#，不依赖临时反汇编库。

```powershell
python -B tools/ra3_mirage/audit_laser_cpu.py --game '<起义>/Data/ra3ep1_1.1.game' --output refs/ra3-mirage/code-audit/native-cpu
# 显式更新基线时追加 --fixture iron_tide/tests/fixtures/ra3_laser_cpu.json
```

原指令片段SHA256 `dbdb8c4a4fb712bf343d911ace0577c0840ac6274e3b9f754f79f45193b84c62`。35组、1120项位置/UV/透明度检查通过，最大绝对误差`4.21e-6`；覆盖不同宽度、方向/高度、时间偏移、渐入/渐出、-1无限时长、零长/极短段。选定16组原指令输出保存为轻量JSON基线，Godot实现直接与之比较。

Godot六组463项通过：presentation100、lethal_beam25、sdk_timing116、damage_adapter23、mirage79、savegame120。独立GPU视口与双线性Clamp-U/Wrap-V参考逐点对比。固定CPU opacity=1时，0.2/0.75/1.25/1.49秒总RGB能量约4627.68/1758.53/212.22/29.86，3秒为0，无横向回卷重亮。首次参考遗漏RGBA8在混合前钳制源RGB，产生一项失败；纠正测试的帧缓冲模型后全部重跑通过，未放宽容差。

证据：`refs/ra3-mirage/code-audit/native-cpu/audit.json`、`refs/ra3-mirage/integration-test/native-laser/final/audit.json`。Godot4.7.2/OpenGL Compatibility/WASAPI，隔离user_data `CodexIronTideValidation/ra3-mirage-20261027`；无网络、数据库、业务服务。测试期间及收尾复查源码/配置/贴图指纹未变。共享版本已由其它任务推进到0.3.10，本次追加第四段；其它功能不属于本次提交与验收。验证针对共享工作区，不等于干净检出或发行包；实机粗细及淡出观感仍待用户确认。
