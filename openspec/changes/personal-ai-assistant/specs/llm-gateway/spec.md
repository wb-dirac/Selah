## ADDED Requirements

### Requirement: 多提供商接入
系统 SHALL 支持通过统一接口接入以下 LLM 提供商：OpenAI、Anthropic、Google Gemini、DeepSeek、智谱 AI、月之暗面、百川 AI、自定义 OpenAI Compatible 端点、Ollama（本地）、LM Studio（本地）、llama.cpp（本地）、MLX（Apple Silicon 本地）。

#### Scenario: 添加 OpenAI 提供商
- **WHEN** 用户在设置页选择 "OpenAI"，输入有效 API Key 并点击保存
- **THEN** 系统 SHALL 对 Key 执行可用性测试，测试通过后将 Key 加密存入 OS KeyChain / KeyStore，并在提供商列表显示可用状态

#### Scenario: 添加自定义 OpenAI Compatible 端点
- **WHEN** 用户选择"自定义端点"，填写 Base URL、API Key 并保存
- **THEN** 系统 SHALL 向该 URL 发送 `/models` 请求验证连通性，成功后列出可用模型供选择

#### Scenario: 添加 Ollama 本地提供商
- **WHEN** 用户选择 Ollama，填写本地地址（默认 `http://localhost:11434`）
- **THEN** 系统 SHALL 检测 Ollama 服务连通性，列出已拉取的本地模型

### Requirement: API Key 安全存储
系统 SHALL 使用 iOS KeyChain / Android KeyStore / macOS KeyChain / Windows DPAPI 存储所有 API Key，API Key 不得以明文形式写入任何文件或日志。

#### Scenario: Key 存入后无法通过文件系统读取
- **WHEN** API Key 保存成功
- **THEN** 系统 SHALL 将 Key 存入 OS 原生加密存储，UI 仅显示脱敏形式（如 `sk-...ab12`），日志中 Key 全部替换为 `[REDACTED]`

#### Scenario: 内存中 Key 使用后立即清除
- **WHEN** LLM 请求完成
- **THEN** 系统 SHALL 清除内存中持有的 Key 引用，不得缓存明文 Key

### Requirement: 模型路由策略
系统 SHALL 支持可配置的智能路由规则，将请求路由到合适的模型。

#### Scenario: 按任务复杂度路由
- **WHEN** 用户发送简单问答请求（Prompt token < 500）且配置了本地小模型
- **THEN** 系统 SHALL 优先路由到本地 ≤4B 参数模型

#### Scenario: 按模态自动路由
- **WHEN** 用户附带图片输入且当前主模型不支持多模态
- **THEN** 系统 SHALL 自动路由到用户配置的多模态备用模型，并在 UI 提示路由原因

#### Scenario: Fallback 机制
- **WHEN** 主模型请求失败（HTTP 5xx 或网络超时）
- **THEN** 系统 SHALL 自动切换到用户配置的备用模型，最多重试 2 次，并在 UI 角落以 toast 提示"已切换到备用模型"

### Requirement: Token 用量统计
系统 SHALL 记录每个云端提供商的当月 Token 用量，并在配置页展示。

#### Scenario: 达到用量告警阈值
- **WHEN** 当月 Token 用量超过用户设置的告警上限
- **THEN** 系统 SHALL 在对话界面顶部展示告警横幅，提示用户剩余配额

### Requirement: 配置导入导出
系统 SHALL 支持导出提供商配置（不含 API Key）并在新设备导入。

#### Scenario: 导出配置
- **WHEN** 用户点击"导出配置"
- **THEN** 系统 SHALL 生成 JSON 文件，其中所有 API Key 字段替换为空字符串，用户可通过系统分享菜单导出
