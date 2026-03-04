## 6. 技术选型

| 层次 | 选型 | 备选方案 | 选择原因 |
|------|------|----------|----------|
| **跨平台框架** | Flutter | React Native | 原生性能好，单代码库覆盖 iOS/Android/macOS/Windows |
| **本地 LLM 推理** | llama.cpp + MLX (Apple) | ONNX Runtime | 社区活跃，模型支持广泛，MLX 在 Apple 设备性能最优 |
| **本地模型管理** | Ollama | LM Studio | API 标准化，支持多种模型，易于集成 |
| **本地数据库** | SQLite (SQLCipher) | Realm | 成熟稳定，加密支持完善，文件可备份 |
| **向量数据库** | sqlite-vec | Objectbox Vector | 与 SQLite 集成，无额外依赖 |
| **VAD** | Silero VAD | WebRTC VAD | 精度高，模型小（约 1MB），支持多语言 |
| **本地 STT** | Whisper.cpp | — | 最佳开源 STT，支持中文，可本地运行 |
| **本地 TTS** | Kokoro | Piper | 音质好，模型小，支持中文 |
| **JS 沙箱** | QuickJS | Hermes | 轻量（约 200KB），支持 ES2020，易于嵌入 |
| **A2A 通信** | HTTP/2 + gRPC | WebSocket | A2A 协议官方推荐，支持流式传输 |
| **加密** | AES-256-GCM + Argon2 | ChaCha20-Poly1305 | 业界标准，平台原生支持 |
| **后台任务** | WorkManager / BGTaskScheduler | — | 平台原生最佳实践 |

---

