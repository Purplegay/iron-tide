# v0.25.68.2 · 查看被动与天赋时暂停

此前详情面板只拦截输入，战斗继续推进。现在从技能栏打开被动／天赋详情时，同时暂停 SceneTree 和 battle.paused；面板使用 PROCESS_MODE_ALWAYS 保持滚动、刷新与关闭响应。

关闭按钮或 Esc 移除面板后，恢复打开前的两个暂停标记并同步顶部暂停按钮。原先已暂停的对局不会被意外继续；重复打开由现有 modal_count 拦截，不覆盖原状态。目标离场只更新说明，不提前解除暂停。若对局已结束，不覆盖结算流程管理的暂停状态。提示改为“对局已暂停”。

## 验证

battle_inspection_regression：128 项通过，覆盖 RA2／扩展两模式的真实技能栏打开入口、面板继续处理、两个暂停标记、重复打开、目标离场、关闭恢复、Esc 和不同原始暂停状态，以及既有被动／天赋说明与改键检查。

隔离源码和 APPDATA，Godot --headless + CREATE_NO_WINDOW。无可见窗口、玩家存档、网络、服务或数据库操作。进程退出 0，无 ERROR 或 SCRIPT ERROR；实现及测试文件与验证快照逐字节一致。证据 C:/Users/admin/Temp/iron-passive-pause-20261105-a/。

本次只接入既有对局暂停机制，不改武器、养成、结算或存档数据。文案显示仍为 pending_user_visual_confirmation；暂停状态逻辑已验证。未提交、推送或打包，保留其它并行工作。
