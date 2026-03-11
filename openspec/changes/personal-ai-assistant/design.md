## Context

项目基于现有 Flutter 框架骨架构建跨平台智能个人助理 App，目标平台为 iOS 16+ / Android 10+ / macOS 13+ / Windows 11。现有代码库仅含 Flutter 项目脚手架（`lib/main.dart`，无业务逻辑）。所有核心逻辑均为从零构建。

核心约束：
- **隐私优先**：API Key / 对话历史 / 联系人缓存等敏感数据严禁上云，必须使用 OS 原生 KeyChain/KeyStore 或 SQLCipher 加密本地存储
- **用户持有 Key**：不提供任何中转代理服务，用户直接持有并管理所有 LLM API Key
- **离线可用**：配置本地模型后核心对话功能须在无网络环境下正常运行
- **开源**：代码完全开源，架构须易于社区审查和贡献

## Goals / Non-Goals

**Goals:**
- 在 Flutter 单代码库实现 iOS / Android / macOS / Windows 四端一致的助理体验
- 构建可扩展的 LLM 网关层，支持 10+ 提供商及本地模型无缝切换
- 实现安全、隔离的 Skill 沙箱执行环境（Pyodide / QuickJS）
- 完整实现 Anthropic Agent Skill 三层加载标准
- 完整实现 Google A2A 协议 Host / Remote 双角色
- 建立分级权限（L0-L3）Tool Bridge，所有原生能力调用透明可审计

**Non-Goals:**
- 不提供自训练 / Fine-tune 模型能力
- 不提供云端数据存储服务（Phase 2 的 GitHub Gist 同步为用户数据，非服务数据）
- 不支持图片生成（移动端算力不可行）
- 不构建多用户 / 团队协作功能
- 不自建 Skill 市场和 Agent 发现目录（对接已有开放生态）

## Decisions

### 决策 1：跨平台框架选 Flutter 而非 React Native
**选择**：Flutter  
**原因**：原生渲染性能更好，Dart 生态对 FFI 调用 llama.cpp 等原生库更直接；单代码库覆盖 iOS / Android / macOS / Windows 四端；生成式 UI 组件渲染一致性更高。  
**备选**：React Native（JS 桥接开销影响 LLM 推理性能；原生库集成更复杂）

### 决策 2：LLM 接入层统一抽象为 Gateway
**选择**：在应用层构建 `LLMGateway` 抽象，所有 LLM Provider 实现统一接口  
**原因**：用户可自由切换提供商而无需改动上层代码；模型路由策略（按复杂度/模态/成本）可集中管理；Fallback 机制易于实现。  
**接口设计**：
```
LLMGateway
  ├── chat(messages, options) → Stream<ChatChunk>
  ├── embed(text) → Vector
  └── listModels() → List<Model>
```

### 决策 3：本地存储采用 SQLCipher + sqlite-vec
**选择**：SQLite + SQLCipher 加密，向量存储用 sqlite-vec 扩展  
**原因**：SQLCipher 成熟稳定，AES-256 加密，文件可备份；sqlite-vec 与 SQLite 同文件，无额外进程依赖；避免引入 Realm 或独立向量数据库增加复杂度。  
**备选**：Objectbox（闭源商业成分，不符合全开源理念）

### 决策 4：Skill 沙箱分类型使用不同运行时
**选择**：Python → Pyodide（WASM）；JS → QuickJS VM；Shell → 受限 bash 白名单  
**原因**：Pyodide 在 WASM 层提供天然内存隔离；QuickJS 约 200KB，嵌入成本低且支持 ES2020；Shell 通过命令白名单降低攻击面。  
**网络策略**：沙箱内默认无网络访问，与 Anthropic 官方 Skill 运行环境标准一致。

### 决策 5：A2A 走 HTTP/2 + gRPC 而非 WebSocket
**选择**：HTTP/2 + gRPC  
**原因**：A2A 协议官方推荐，支持双向流式传输；gRPC 有完整的 Flutter/Dart 客户端库；WebSocket 在移动端网络切换时连接稳定性较差。

### 决策 6：后台任务使用平台原生 API
**选择**：iOS `BGTaskScheduler` / Android `WorkManager` / 桌面系统 Cron  
**原因**：平台原生 API 与系统电池优化体系集成，不会被系统杀死；没有比这更优的跨平台方案。  
**限制应对**：iOS 后台执行时间受限时降级为通知提醒，引导用户设置通知权限。

### 决策 7：架构分层 — 四层模型
```
表现层    (Flutter Widgets, Generative UI Runtime)
编排层    (Agent Core, Task Planner, Context Manager)
能力层    (LLM Gateway, Tool Bridge, Skill Sandbox, A2A Client)
存储层    (SQLCipher DB, OS KeyChain, sqlite-vec)
```
各层通过明确的接口通信，能力层可独立测试，表现层不直接访问存储层。

## Risks / Trade-offs

- **本地模型内存 OOM** → 动态卸载模型，4GB RAM 设备限制最大 7B 参数，首次配置时提示规格建议
- **iOS 后台执行时间受系统限制** → 降级为推送通知方案，任务逻辑执行移至前台打开时补偿
- **Skill 沙箱性能开销（Pyodide ~2MB WASM 初始化）** → 懒加载，首次激活后缓存实例
- **A2A 协议尚处早期，生态不成熟** → Phase 3 接入，保持 A2A 客户端为可替换的抽象层
- **多模态语音输入依赖云端提供商可用性** → 提供文本输入与离线模式降级；语音入口在无可用提供商时禁用并给出明确提示
- **QuickJS 安全审计覆盖有限** → 用 AST 静态扫描作为第一道防线；QuickJS 无 DOM / 无文件系统访问作为第二层
- **GitHub Gist 同步在弱网下可能冲突** → Last-write-wins + 同步前 diff 展示 + 本地快照保留 7 天

## Migration Plan

1. **Phase 1**：在现有 Flutter 骨架基础上搭建四层架构，交付 MVP（LLM 接入 + 文字/图片对话 + 基础工具 + 本地加密存储）
2. **Phase 2**：增量添加语音能力、Skill 沙箱、定时任务、GitHub Gist 同步
3. **Phase 3**：A2A 协议、实时语音、Windows 适配、PII 检测
4. **回滚策略**：每个 Phase 独立发布，各模块通过 Feature Flag 控制，异常时可快速关闭单一模块而不影响核心对话功能

## Open Questions

- SQLCipher Flutter 插件在 Windows 端的成熟度（需预研 `sqflite_sqlcipher` 的 Windows 支持情况）
- Pyodide 在 Flutter iOS/Android 端通过 Flutter Web Worker 集成的方案可行性（备选：通过 dart:ffi 调用原生 WASM runtime）
- A2A 协议 gRPC 与 Dart gRPC 库的流式传输兼容性（需在 Phase 3 启动前验证）
