# 通用科技医院占领颜色（2026-11-26）

玩家截图的蓝边屋顶与 `assets/ra2/shp/CATHOSP.png` 第一帧吻合，不是好莱坞的城市版。通用贴图的房色阶是烘焙蓝，原来医院材质只匹配纯红阶及外墙，导致选中黄框独立显示但屋顶始终是蓝色。通用贴图的红十字也有纯红像素，不能给两版简单合并判定。

`HouseColor.apply_to` 按建筑实际加载的贴图路径区分两版；通用版中立走 `HOSPITAL_BLUE_NEUTRAL` 用灰色，有主走 `HOSPITAL_BLUE_FACADE` 用所有者房色并保留原外墙薄涂。`shaders/house_remap.gdshader` 对这两个模式只把烘焙蓝当作房色阶，不套纯红规则；原城市医院、机场、维修厂的既有分支不变。占领沿用 `AlliedAbilities.change_side` 当步刷新材质，不改玩法或存档。

Godot 4.7.2、Compatibility/OpenGL、隔离 APPDATA 运行 `tests/hospital_capture_color.tscn`，由真实隐秘山谷遭遇战载入医院，明确设置玩家为红色，向苏军工程师下达正式占领命令、将其置于入口并执行正式进门处理。验证立即换边、消耗工程师和材质换色。以战场医院的实际贴图与材质在独立 SubViewport 渲染，灰、红各 1327 个蓝阶像素正确转换，202 个原有红色细节均保留（含纯红），10/10，退出 0，stderr 空。对照渲染和日志：`docs/memory/evidence/hospital-capture-color/`。

好莱坞 `tests/hollywood_campaign.tscn -- --capture-aid` 复核中立灰、占领及同进程快照恢复的医院色均通过。整套退出 1：测试第 175 行伞兵落地检查访问了已释放单位，故不计整套通过；本轮不修改此流程，也未做无改动基线复测。未测试受损姿态、冷进程读档、从远处自然走到入口及打包；对照图为真实材质渲染，不是整张战场截图。未修改玩家存档。
