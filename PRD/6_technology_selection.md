## 6. 技术选型

| 层次 | 选型 | 备选方案 | 选择原因 |
|------|------|----------|----------|
| **跨平台框架** | Flutter | React Native | 原生性能好，单代码库覆盖 iOS/Android/macOS/Windows |
| **本地 LLM 推理** | llama.cpp + MLX (Apple) | ONNX Runtime | 社区活跃，模型支持广泛，MLX 在 Apple 设备性能最优 |
| **本地模型管理** | Ollama | LM Studio | API 标准化，支持多种模型，易于集成 |
| **本地数据库** | SQLite (SQLCipher) | Realm | 成熟稳定，加密支持完善，文件可备份 |
| **向量数据库** | sqlite-vec | Objectbox Vector | 与 SQLite 集成，无额外依赖 |
| **语音输入理解** | 多模态 LLM 音频输入 | 本地 STT（后续可选） | 降低端侧推理复杂度，统一多模态链路 |
| **TTS** | 供应商 TTS 模型（按用户选择） | 本地 TTS（后续可选） | 音色与自然度更稳定，便于跨平台一致性 |
| **JS 沙箱** | QuickJS | Hermes | 轻量（约 200KB），支持 ES2020，易于嵌入 |
| **A2A 通信** | HTTP/2 + gRPC | WebSocket | A2A 协议官方推荐，支持流式传输 |
| **加密** | AES-256-GCM + Argon2 | ChaCha20-Poly1305 | 业界标准，平台原生支持 |
| **后台任务** | WorkManager / BGTaskScheduler | — | 平台原生最佳实践 |

---

