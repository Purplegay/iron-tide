# v0.25.11.5 · 相位余辉匣蓝白尾流

未来坦克的 3D 材质已经完成阵营色蒙版。最终绘制到 2D 战场时跳过尤复房色匹配，保留时空、C4 等状态绘制。喷流采用内置 imagegen 生成的透明侧视纹理，再由着色器向后推进、收尾渐隐。

## 美术输入

工具为内置 imagegen，透明 PNG 导入 `iron_tide/assets/cosmetics/mounts/future_phase_exhaust.png`。生成提示词如下。

Game VFX texture, a single realistic blue-white ion thruster exhaust, strict orthographic side profile. A small flat vertical emitting edge at the extreme left halfway up; a coherent luminous white cyan core reaches downstream to the right, subtle irregular shock diamonds, translucent cobalt blue gaseous shear layers and long wisps gradually dissipating toward the right edge. Physically plausible gas turbulence, compact and directional, slightly asymmetric, thin and long. Wide horizontal composition. True transparent alpha outside and through the diffuse edges. No nozzle, machinery, metal, ground, shadow, explosion, sparks, red, text, or background. This is a game-ready isolated sprite for sampling and animating on an in-game quad.
