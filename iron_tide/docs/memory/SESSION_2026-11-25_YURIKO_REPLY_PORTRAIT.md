# 赠礼回应页恢复百合子立绘

回看赠礼回应时，页面重建只装入列表。`scripts/screens/yuriko_school.gd` 现让私信主页与回应页共用 `add_gift_portrait()`，读取当前穿戴造型并沿用同一布局。

`tests/yuriko_school_regression.gd` 从手记点击私信、回看、返回，核对回应页立绘可见、纹理相同且位置尺寸一致。独立档案 Godot 4.7.2 无头测试 1281 项通过。验证范围为源码场景和控件属性。日志在 `%TEMP%/YurikoReply-dd75c3e6/result.log`。
