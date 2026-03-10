## 1. 项目架构搭建

- [x] 1.1 配置 Flutter 四层架构目录结构（presentation / orchestration / capability / storage）
- [x] 1.2 配置 flutter_lints 及分析规则（analysis_options.yaml）
- [x] 1.3 添加核心依赖：sqflite_sqlcipher、flutter_secure_storage、riverpod / bloc 状态管理
- [x] 1.4 实现 Feature Flag 基础设施，支持按模块开关功能
- [x] 1.5 配置 iOS / Android / macOS / Windows 各平台基础权限清单
- [x] 1.6 搭建基础路由框架（go_router）和 App 主题（深色/浅色模式）

## 2. 本地安全存储层

- [x] 2.1 实现 SQLCipher 数据库初始化，密钥托管至 OS KeyChain/KeyStore
- [x] 2.2 实现对话历史 Schema（conversations / messages 表）及 CRUD DAO
- [x] 2.3 实现 sqlite-vec 向量扩展集成，建立文档片段向量表
- [x] 2.4 实现数据保留策略定时清理（默认 90 天，可配置）
- [x] 2.5 实现"一键清除所有本地数据"功能及二次确认流程
- [x] 2.6 实现日志系统 API Key 自动脱敏（`[REDACTED]` 替换）

## 3. LLM 网关层

- [x] 3.1 定义 `LLMGateway` 抽象接口（chat stream / embed / listModels）
- [x] 3.2 实现 OpenAI Compatible Provider（支持 OpenAI / DeepSeek / 智谱 / 月之暗面 / 百川 / 自定义端点）
- [x] 3.3 实现 Anthropic Provider（Claude 系列，原生 API）
- [x] 3.4 实现 Google Gemini Provider
- [x] 3.5 实现 Ollama 本地 Provider
- [x] 3.6 实现 API Key 加密存储与读取（OS KeyChain/KeyStore 封装）
- [x] 3.7 实现模型路由策略引擎（按复杂度、按模态、Fallback）
- [x] 3.8 实现 API Key 可用性测试（添加 Provider 时自动触发）
- [x] 3.9 实现 Token 用量统计记录与月度告警阈值通知
- [x] 3.10 实现 Provider 配置导入/导出（Key 字段置空）

## 4. 多模态对话界面

- [x] 4.1 实现基础对话 UI（气泡列表、输入框、发送按钮）
- [x] 4.2 集成 Markdown 渲染库（flutter_markdown），支持代码高亮、表格、KaTeX 公式
- [x] 4.3 实现对话历史分页加载与搜索功能
- [x] 4.4 实现消息 Re-generate（分支重试）和分支切换 UI
- [x] 4.5 实现上下文窗口自动压缩（摘要 + 分隔符提示）
- [x] 4.6 实现图片输入（相机拍摄 / 相册选取 / 截图粘贴 / 桌面拖拽）
- [x] 4.7 集成本地 OCR（Apple Vision / Google ML Kit）
- [x] 4.8 实现发送图片至云端 LLM 前的隐私确认弹窗
- [x] 4.9 实现文件输入（PDF / Word / Excel / TXT / CSV / Markdown 解析）
- [x] 4.10 实现超长文档 RAG 分块索引与检索（sqlite-vec）
- [ ] 4.11 集成 Whisper.cpp（本地 STT）+ Silero VAD（语音活动检测）
- [ ] 4.12 集成 Kokoro / Piper（本地 TTS），实现流式句子级合成播放
- [ ] 4.13 实现实时全双工语音模式（Google Live API 接入）
- [ ] 4.14 实现全屏沉浸式实时对话 UI（波形动画、Barge-in 支持、实时字幕）

## 5. 生成式 UI 运行时

- [x] 5.1 定义 UIComponentRegistry 及 `UIComponentDefinition` 接口
- [x] 5.2 实现 LLM 响应流 JSON Schema 解析器（提取 ui_type 块）
- [x] 5.3 实现 `product_card` 组件（图片、价格、评分、操作按钮）
- [x] 5.4 实现 `calendar_event` 组件（含"添加到日历"交互按钮）
- [x] 5.5 实现 `contact_card` 组件（含"拨打"/"发邮件"交互按钮）
- [x] 5.6 实现 `map_preview` 组件（静态地图图片 + 导航按钮）
- [x] 5.7 实现 `flight_card` / `train_card` 组件
- [x] 5.8 实现 `weather_card` 组件
- [x] 5.9 实现 `code_block` 组件（高亮、复制、在沙箱中运行）
- [x] 5.10 实现 `task_list` 组件（可勾选状态）
- [x] 5.11 实现 `price_chart` 组件（时间轴折线图）
- [x] 5.12 实现未知 ui_type 降级展示（格式化 JSON 代码块）
- [x] 5.13 实现响应式布局适配（手机/平板/桌面）和深色模式自适应

## 6. 原生能力 Tool Bridge

- [x] 6.1 定义 Tool 抽象接口及四级权限分级枚举（L0-L3）
- [x] 6.2 实现权限状态持久化存储（L1 授权记录）
- [x] 6.3 实现工具调用确认弹窗组件（L1 首次 / L2 每次 / L3 完整预览）
- [ ] 6.4 实现通信类工具：读取联系人、搜索联系人（L1）、创建联系人（L2）
- [ ] 6.5 实现通信类工具：发送邮件草稿（L2）、发送短信（L2）、拨打电话（L3）
- [ ] 6.6 实现日历工具：读取事件（L1）、创建事件（L2）、修改/删除事件（L2，含前后对比 UI）
- [ ] 6.7 实现位置工具：获取当前位置（L1，仅内存）、地点搜索（L0）
- [x] 6.8 实现 URL Scheme 唤起地图（高德 / 百度 / Google Maps）、微信、支付宝、钉钉、飞书
- [x] 6.9 实现系统工具：读取/写入剪贴板、系统分享菜单
- [x] 6.10 实现对话界面工具调用状态实时显示（"正在调用：XXX…"提示）
- [x] 6.11 实现设置页工具调用历史日志与权限撤销功能

## 7. Agent Skill 沙箱

- [x] 7.1 实现 `SKILL.md` YAML frontmatter 解析器（name / description 校验）
- [x] 7.2 实现 Skill 三层加载机制（Level 1/2/3 按需加载）
- [ ] 7.3 集成 Pyodide WASM，封装 Python 沙箱执行接口（禁网络、禁文件系统）
- [ ] 7.4 集成 QuickJS VM，封装 JS 沙箱执行接口（无 DOM / 无原生模块）
- [ ] 7.5 实现 Shell 脚本受限 bash 白名单执行环境
- [ ] 7.6 实现沙箱资源限制（30s 超时 / 128MB 内存 / 100MB 临时文件）
- [x] 7.7 实现 Skill 安装 AST 静态扫描（Python os.system/subprocess/socket 检测）
- [x] 7.8 实现 Skill 安装 prompt injection 特征检测
- [x] 7.9 实现 Skill 安装流程 UI（下载 → 解压 → 扫描 → 确认 → 安装）
- [ ] 7.10 实现 Skill 市场对接（Anthropic 目录 + GitHub 社区索引 + 自定义源）
- [x] 7.11 实现 Skill 管理界面（列表、详情、启用/禁用/卸载、运行日志）
- [ ] 7.12 实现 UIComponentRegistry 的 Skill 扩展注册 API

## 8. 后台定时任务引擎

- [x] 8.1 实现任务定义数据模型（任务类型 / Cron 表达式 / 触发条件 / 关联操作）
- [ ] 8.2 实现 iOS BGTaskScheduler + BGProcessingTask 集成
- [ ] 8.3 实现 Android WorkManager + AlarmManager 集成
- [ ] 8.4 实现 macOS / Windows 系统 Cron / Task Scheduler 集成
- [ ] 8.5 实现地理围栏监听（iOS CLLocationManager / Android Geofencing API）
- [ ] 8.6 实现后台轻量模型推理决策流程（≤4B 模型，≤1s）
- [ ] 8.7 实现通知快捷操作按钮（稍后提醒 / 已完成 / 立即处理）
- [ ] 8.8 实现 iOS 后台时间不足时降级为推送通知补偿逻辑
- [ ] 8.9 实现 Android 电池优化白名单引导流程
- [x] 8.10 实现任务管理 UI（任务列表 / 下次触发时间 / 执行历史日志）

## 9. A2A 协议

- [x] 9.1 实现 Agent Card 数据结构及 `/.well-known/agent.json` 端点
- [ ] 9.2 实现 A2A Host 客户端（HTTP/2 + gRPC，流式请求）
- [ ] 9.3 实现 A2A Remote Agent 服务端（可选开启，含认证）
- [ ] 9.4 实现 OAuth 2.0 和 API Key 两种 Agent 认证方式
- [x] 9.5 实现 mDNS / Bonjour 局域网 Agent 自动发现
- [ ] 9.6 实现手动添加 Agent（二维码扫描 + URL 直接输入）
- [ ] 9.7 对接公开 A2A 注册目录，实现 Agent 浏览与搜索 UI
- [x] 9.8 实现外部 Agent 调用前用户确认预览界面
- [ ] 9.9 实现 TLS 1.3 版本验证，低版本拒绝连接
- [ ] 9.10 实现外部 Agent 返回数据沙箱隔离处理（禁止宿主直接 eval）

## 10. 隐私与安全加固

- [x] 10.1 集成本地轻量 NER 模型，实现手机号 / 身份证号 / 银行卡号 PII 检测
- [x] 10.2 实现"发送前确认"模式 UI（Prompt 预览 + PII 高亮标注）
- [x] 10.3 实现联系人姓名自动代号替换（会话级一致性）
- [ ] 10.4 实现 GitHub Gist OAuth 授权流程（仅申请 gist 权限范围）
- [ ] 10.5 实现 Argon2id passphrase → 密钥派生，AES-256-GCM 加密同步数据
- [ ] 10.6 实现同步冲突检测与 diff 展示 UI，支持用户手动仲裁
- [x] 10.7 确认 API Key 字段在同步序列化时严格排除
- [ ] 10.8 实现本地快照保留（同步前保存 7 天快照，防止数据丢失）

## 11. 设置中心与配置 UI

- [x] 11.1 实现 LLM 提供商管理页（列表 / 添加 / 编辑 / 删除 / 可用性测试）
- [x] 11.2 实现模型路由规则配置页
- [x] 11.3 实现权限管理页（工具授权记录 / 撤销入口）
- [x] 11.4 实现隐私设置页（PII 检测开关 / 数据保留天数 / 一键清除）
- [x] 11.5 实现跨设备同步配置页（GitHub 授权 / passphrase 设置 / 同步状态）
- [x] 11.6 实现可访问性支持（VoiceOver / TalkBack / 高对比度 / 字体大小跟随系统）
