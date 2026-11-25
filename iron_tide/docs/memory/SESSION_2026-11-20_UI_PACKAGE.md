# UI更新打包交付

用户要求打包，已用tools/package_windows.py冻结当前工程12131文件，版本0.30.48.5。Stage iron_tide/.validation/package-ui-20261120。模板为iron_tide/IronTideRuntime.exe，Godot4.7.2与编辑器版本一致。导入、导出、成品主菜单、真实导出Release战场smoke均exit0 errors0，95 checks failed0。smoke含原生地图加载、模拟推进、性能JSON生成及大型checkpoint恢复，使用已有验证fixture ../.validation/core-five-20261113/slot1.itsave，仅复制到隔离profile，不改玩家存档。ZIP完整性及逐文件sha256通过，源码冻结与归档前无漂移。

交付IronTide-0.30.48.5-20261120-UI.zip，331284562字节，SHA256 08cdb95b47edf9f7cbadd3a077e4a41ae7707754bdfa65ff965d8868d956223b。文件在本会话sandbox，交付使用create_download。包内IronTide.exe+IronTide.pck、许可及说明、manifest；存档目录APPDATA/IronTideFriends。包含当前工作区并行已有修改，不仅UI；未commit，不宣称性能目标达成。

包含按钮连接警示条、原生槽体、右下角选择列表。开发场景UI17/17通过，已截图检查；成品smoke是headless，不代表新增成品图形验收。持久记忆已满，记录保存在此。
