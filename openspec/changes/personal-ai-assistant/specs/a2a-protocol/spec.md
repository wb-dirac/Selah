## ADDED Requirements

### Requirement: Host Agent 角色——调用外部 Agent
系统 SHALL 作为 A2A Host Agent，通过 HTTPS 向已注册的 Remote Agent 发起任务请求，支持流式响应和 Push Notification 回调。

#### Scenario: 调用外部 Agent 获取航班信息
- **WHEN** 本地 Agent Core 判断需要调用铁路信息 Agent（通过 A2A）
- **THEN** 系统 SHALL 向 Agent Card URL 发起 A2A 请求，以流式方式接收班次数据，渲染为 `train_card` 生成式 UI

#### Scenario: 外部 Agent 调用前展示预览
- **WHEN** Agent Core 请求调用注册的外部 Remote Agent
- **THEN** 系统 SHALL 在执行前向用户展示"即将调用 [Agent 名称] 执行 [操作描述]"确认提示，用户可拒绝

### Requirement: Remote Agent 角色——被外部系统调用
系统 SHALL 可选开启 Remote Agent 模式，对外暴露 A2A 端点（`/a2a`），响应外部 Host Agent 的请求。

#### Scenario: 外部 Host 调用本助理的日程管理 Skill
- **WHEN** 外部 Host Agent 向本应用的 A2A 端点发送创建日历事件任务
- **THEN** 系统 SHALL 验证请求认证信息，执行日历创建工具，返回操作结果

### Requirement: Agent Card 规范
系统 SHALL 按 A2A 协议生成标准 Agent Card，包含 `name`、`description`、`url`、`version`、`capabilities`（streaming / pushNotifications / stateTransitionHistory）和 `skills` 数组。

#### Scenario: Agent Card 可通过 URL 访问
- **WHEN** Remote Agent 模式已开启，任意 HTTP 客户端 GET `/.well-known/agent.json`
- **THEN** 系统 SHALL 返回合法的 A2A Agent Card JSON

### Requirement: 服务发现——mDNS 局域网
系统 SHALL 通过 mDNS / Bonjour 自动发现同一局域网内运行的 A2A Agent 服务，无需手动配置。

#### Scenario: 自动发现局域网 Agent
- **WHEN** 应用在局域网环境中启动，且有其他设备运行兼容 A2A 服务
- **THEN** 系统 SHALL 在 Agent 发现列表自动显示该服务，包含其 Agent Card 信息

### Requirement: 服务发现——手动添加与公开目录
系统 SHALL 支持通过扫描二维码或直接输入 URL 手动添加 Agent，以及对接已有公开 A2A 注册目录浏览可用 Agent 服务。

#### Scenario: 扫描二维码添加 Agent
- **WHEN** 用户扫描 Agent 服务提供的二维码
- **THEN** 系统 SHALL 解析 Agent Card URL，获取 Agent 信息后展示确认添加界面

### Requirement: A2A 通信安全
所有 A2A 通信 SHALL 使用 HTTPS（TLS 1.3+），支持 OAuth 2.0 和 API Key 两种认证方式，外部 Agent 返回数据须在本地沙箱处理，不直接执行任意代码。

#### Scenario: TLS 版本低于 1.3 时拒绝连接
- **WHEN** 系统尝试连接目标 Agent 服务器但协商的 TLS 版本低于 1.3
- **THEN** 系统 SHALL 拒绝建立连接，向用户显示"该 Agent 服务安全配置不符合要求"

#### Scenario: 外部 Agent 返回数据不直接执行
- **WHEN** 外部 Agent 返回包含可执行代码的响应体
- **THEN** 系统 SHALL 将响应数据作为纯文本传递给 LLM，不在宿主环境直接 eval 执行
