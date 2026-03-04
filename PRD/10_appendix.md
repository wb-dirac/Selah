## 10. 附录

### 10.1 术语表

| 术语 | 说明 |
|------|------|
| LLM | Large Language Model，大型语言模型 |
| A2A | Agent-to-Agent，Google 提出的 Agent 间通信协议 |
| Agent Skill | Anthropic 定义的 Agent 扩展能力标准。每个 Skill 是一个目录，核心文件为 `SKILL.md`（含 YAML frontmatter 元数据 + 指令正文），可附带脚本和资源文件。Claude 按需读取 SKILL.md 并通过 bash 调用脚本 |
| VAD | Voice Activity Detection，语音活动检测 |
| STT | Speech-to-Text，语音转文字 |
| TTS | Text-to-Speech，文字转语音 |
| RAG | Retrieval-Augmented Generation，检索增强生成 |
| PII | Personally Identifiable Information，个人身份信息 |
| URL Scheme | 移动端唤起第三方 App 的 URL 协议 |
| Barge-in | 用户打断 AI 正在播放的语音 |
| KeyChain | iOS / macOS 系统级加密密钥存储 |
| KeyStore | Android 系统级加密密钥存储 |
| GitHub Gist | GitHub 提供的代码片段/文件托管服务，本产品用作跨设备同步的加密数据中转 |
| AST | Abstract Syntax Tree，抽象语法树，用于静态分析 Skill 脚本安全性 |

### 10.2 参考资料

- [Google A2A Protocol Specification](https://google.github.io/A2A/)
- [Anthropic Agent Skill Specification](https://docs.anthropic.com/en/docs/agents)
- [OpenAI Realtime API Documentation](https://platform.openai.com/docs/guides/realtime)
- [Whisper.cpp GitHub](https://github.com/ggerganov/whisper.cpp)
- [Ollama API Documentation](https://ollama.com/docs)
- [Flutter Documentation](https://docs.flutter.dev)
- [SQLCipher Documentation](https://www.zetetic.net/sqlcipher/)
- [QuickJS Documentation](https://bellard.org/quickjs/)
- [GitHub Gist API Documentation](https://docs.github.com/en/rest/gists)

### 10.3 已决策事项

| 事项 | 决策结果 | 决策依据 |
|------|----------|----------|
| 跨设备同步方案 | GitHub Gist + 端对端加密，Phase 2 实现 | 零服务器成本，用户自持数据，对开发者友好 |
| 插件/Skill 标准 | 遵循 Anthropic Agent Skill 标准，不自定义 | 融入现有生态，降低开发者门槛，复用已有 Skill |
| Skill 市场策略 | 对接现有开放市场，支持多源聚合，安装时本地安全扫描 | 不重复建设，开放生态，安全由本地扫描保障 |
| Agent 发现目录 | 接入已有公开 A2A 目录，不自建 | 节省资源，避免冷启动问题，符合开放协议精神 |
| 商业化模式 | **完全开源** | 与隐私优先、用户数据自主的产品理念一致；吸引开发者共建生态 |

### 10.4 开源策略说明

- **开源协议**：待定（建议 MIT 或 Apache 2.0，允许商业使用和二次分发）
- **代码仓库**：GitHub，主仓库包含核心应用代码
- **社区贡献**：接受 Skill 适配、工具扩展、语言本地化等社区贡献
- **扫描规则库**：Skill 安全扫描规则独立开源仓库维护，社区可提交规则
- **分叉说明**：任何人可基于开源代码搭建自己的版本，但须遵守开源协议
