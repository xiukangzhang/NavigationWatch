# NavigationWatch开发约定

先读docs/NEXT_SESSION_HANDOFF.md，再按引用读取必要文档。保留现有用户修改，默认AMap，不新增freshness workaround或自动fallback。只运行相关最小测试；构建、安装、真机验收分开记录。Key使用Config.local.xcconfig，禁止提交密钥、个人定位、日志或构建缓存。UI采用系统字体与原生SwiftUI。
