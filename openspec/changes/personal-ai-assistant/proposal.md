## Why

构建一款以**隐私优先、本地运行**为核心的跨平台智能个人助理 App，满足用户对数据自主权和智能化工作流的双重需求。当前市面缺乏既支持本地 LLM 离线运行、又具备原生系统能力调用和开放 Agent 生态的移动端助理产品。

## What Changes

- 新增跨平台（iOS / Android / macOS / Windows）Flutter 应用框架
- 新增统一 LLM 接入层（云端 + 本地 Ollama/llama.cpp），API Key 本地加密存储
- 新增多模态对话界面，支持文字、图片（OCR）、文件、语音四种输入
- 新增生成式 UI 运行时，LLM 可动态渲染结构化组件卡片（地图、商品、日程等）
- 新增原生能力 Tool Bridge，分级权限模型管理日历、联系人、地图、第三方 App 唤起等工具
- 新增 Anthropic Agent Skill 标准宿主，含沙箱运行环境（Pyodide / QuickJS）及 Skill 市场对接
- 新增后台定时任务引擎（Cron / 位置触发 / 条件触发），使用本地轻量模型决策
- 新增 Google A2A 协议支持，实现 Host / Remote Agent 双角色
- 新增本地安全存储层（SQLCipher + OS KeyChain/KeyStore）

## Capabilities

### New Capabilities

- `llm-gateway`: 统一 LLM 提供商接入层——支持 OpenAI Compatible / Anthropic / Gemini / 本地 Ollama，含模型路由策略、API Key 加密管理、Token 用量统计
- `multimodal-chat`: 多模态对话能力——文字（Markdown 渲染）、图片（OCR + 多模态 LLM）、文件（PDF/Word/Excel RAG）、语音（Whisper STT + Kokoro TTS）及实时全双工语音模式
- `generative-ui`: 生成式 UI 运行时——LLM 输出 JSON Schema 后本地渲染 Flutter 原生组件，内置 10+ 组件类型（product_card / map_preview / calendar_event 等），支持插件扩展注册
- `tool-bridge`: 原生能力 Tool Bridge——四级权限模型（L0-L3），内置通信、日历、位置、文件、第三方 App URL Scheme 工具集，含工具调用透明度 UI
- `agent-skill`: Agent Skill 沙箱宿主——完整实现 Anthropic Agent Skill 标准（SKILL.md 三层加载），Pyodide / QuickJS 沙箱隔离，Skill 市场多源聚合及安装时 AST 静态安全扫描
- `background-tasks`: 后台定时任务引擎——Cron / 相对时间 / 位置围栏 / 条件触发，跨平台（BGTaskScheduler / WorkManager / 系统 Cron），本地 <4B 模型决策推理
- `a2a-protocol`: Google A2A 协议实现——Host + Remote 双角色，Agent Card 规范，mDNS 局域网发现 + 二维码手动添加 + 公开目录接入，HTTPS/TLS 1.3 安全通信
- `privacy-storage`: 隐私与本地安全存储——SQLCipher AES-256 加密、OS KeyChain/KeyStore、PII 检测脱敏、数据生命周期管理，Phase 2 GitHub Gist 跨设备端对端加密同步

### Modified Capabilities

（无已有 Spec，所有能力均为新建）

## Impact

- **代码库**：在现有 Flutter 项目骨架（`lib/`）基础上全新构建，跨 iOS / Android / macOS / Windows 四平台
- **依赖**：引入 llama.cpp / Ollama、SQLCipher、Pyodide、QuickJS、Whisper.cpp、Kokoro TTS、Silero VAD、sqlite-vec 等本地运行时依赖
- **安全**：全部敏感数据必须使用 OS 原生 KeyChain/KeyStore，日志系统必须脱敏 API Key
- **网络**：默认隐私优先，Skill 沙箱及 PII 数据禁止直接出网；云端 LLM 调用明确告知用户
- **平台 API**：iOS `BGTaskScheduler`、Android `WorkManager`、macOS/Windows 系统 Cron；iOS `HealthKit` 及 Android 厂商电池优化白名单需用户手动配置
