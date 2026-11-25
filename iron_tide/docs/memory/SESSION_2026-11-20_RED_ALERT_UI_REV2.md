# RED ALERT连接与已选单位右下角

用户纠正：按钮须连接警示条，从其上方出来；已选单位列表移右下角。

修改 uprising_red_alert_button.gd：按钮x72，隐藏y82，就绪y40（原y-8）；按钮底座与槽体原图上缘重叠，槽体后绘制遮住底座，截图确认连接。hud.gd：_layout_hud和_layout_selection_strip均将sel_strip锚在BOTTOM_RIGHT，left=-SIDEBAR_WIDTH/right=-8/bottom=-8，按内容高度至多180；prod_panel底部为-height-16，避免右下列表交叠。左侧超武_sidebar不再为选择栏预留90。未移动中央完整单位详情。

tests/red_alert_ui_acceptance.gd新增底座重叠、右下角位置、与指令甲板不重叠检查。正式远征隔离GUI17/17通过exit0，无ERROR；证据.validation/red-alert-ui-revision2/final.log、result.json、ready-selected.png、charging.png、active.png。最终ready-selected已view_image检查：按钮底座贴条，上方无悬空间隙，列表在右下角。复用Temp/CodexIronTideValidation-RedAlertFinal独立存档配置。只验证盟军单选布局，未测大量选择/苏联/多分辨率。未打包提交。

持久记忆100条已满，本轮状态以此交接为准；覆盖前一版按钮位置及左侧选择栏布局结论。
