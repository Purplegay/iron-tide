# IronTide 尤复载具外骨骼试验

用户要求验证后记忆。C:/Users/admin/IronTide v0.25.13 用德国坦克杀手 TNKD 验证。先从 VXL/HVA 查实际结构；其炮管在 DUMMY01 车体内。以局部位置与朝向一次装配左右护轨甲和固定战斗室测距仪，复用同一车体 32 向索引及投影原点。离线比较宿主与配件深度后只存透明叠层。原车素材不替换。其他车型不能套用 TNKD 坐标；独立炮塔与车体交叉遮挡、自由挪位和 SHP 步兵骨架均未由此试验证实。

实现与重建入口 ra2pipe/tnkd_exoframe.mjs；证据见 docs/MODEL_RENDERING.md 及 docs/tnkd-exoframe.png。重复烘焙字节相同，32 向均覆盖，703 项展示回归通过。相对侧视的近侧/远侧护甲可见采样 824/0、822/0。记录技术验证，外观仍待使用者确认。RA3 的旧小配件示例在 scripts/units/signature_mount.gd 与 cosmetic_anchor.gd：网格与材料创建后绑定骨骼，部分表面或喷流使用 AI 纹理。
