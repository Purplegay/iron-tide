# 苏联原版 RA2 侧栏素材提取与接入

纠正上一轮用程序化红色横幅替代原版素材的处理。真正原图已在本机找到：C:/Program Files (x86)/Steam/steamapps/common/Command & Conquer Red Alert II/ra2.mix，内嵌 SIDEC02.MIX。此前只搜独立 SIDEC02.MIX 导致漏判资源不存在；今后须检查 RA2.MIX 内嵌归档。

通过既有 ra2pipe/art_lib.mjs 解码 SIDEC02.MIX 的 TOP/TAB01/TAB02/TAB03.SHP，使用同归档 SIDEBAR.PAL，导出16帧至 assets/ra2/ui/soviet/。provenance.json 保存每帧源SHP/调色板/PNG SHA256。提取脚本保存在 .validation/extract_soviet.mjs（运行须设置 RA2_MIX_DIR）。

hud.gd::_ra2_header 苏联使用 soviet/top-0.png、盟军保持 top-0.png；指挥甲板和小地图均切换。原图是黄铜边框灰金属面，已去掉上轮程序化红横幅替代。其余现有控件依然是项目的金属皮肤；导出的TAB未接入（现有页签为文字按钮，并未使用盟军TAB贴图）。不宣称整套HUD变成原版侧栏。

真实 GUI 两阵营 tests/hud_faction_skin_regression.tscn 10/10通过，exit0，无脚本错误；测试断言改为验证精确阵营原图路径，已查看苏联整场截图。隔离目录 C:/Users/admin/AppData/Local/Temp/IronTideOriginalSoviet-9f3608091289483385aef7ef86939270/report；本次复制当前scripts无额外修正，之前警戒表并行类型错误已不出现。未打包提交，未修改玩家存档。

用户较早提出的远征信息面板缩小/调整位置任务仍待完成（runtime.gd面板约280行，尚未修改）。本轮用户要求先开始原版苏联素材提取，优先闭环本项。
