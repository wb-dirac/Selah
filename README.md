<p align="center">
   <img src="./LOGO.png" alt="SELAH" width="200" />
</p>

# SELAH

This project is a personal AI assistant built using the Flutter framework. It provides a chat interface where users can interact with an AI model to receive responses to their queries.

## Features

- Chat interface for real-time communication with the AI.
- User-friendly design with chat bubbles for messages.
- Responsive layout that works on various screen sizes.
- Integration with an AI service to fetch responses.

## Project Structure

```
personal-ai-assistant
├── lib
│   ├── main.dart                # Entry point of the application
│   ├── screens
│   │   └── home_screen.dart     # Main screen with chat interface
│   ├── widgets
│   │   └── chat_bubble.dart      # Widget for displaying chat messages
│   ├── models
│   │   └── message.dart          # Model for chat messages
│   └── services
│       └── ai_service.dart       # Service for interacting with the AI model
├── pubspec.yaml                  # Project configuration and dependencies
├── test
│   └── widget_test.dart          # Widget tests for the application
└── README.md                     # Project documentation
```

## Getting Started

To run this project, ensure you have Flutter installed on your machine. Follow these steps:

1. Clone the repository:
    ```
    git clone <repository-url>
    ```

2. Navigate to the project directory:
    ```
    cd personal-ai-assistant
    ```

3. Install the dependencies:
    ```
    flutter pub get
    ```

4. Run the application:
    ```
    flutter run
    ```
## TODO list

任务执行情况核查报告


  根据对 lib 目录及相关实现文件的深入分析，现就 @openspec/changes/personal-ai-assistant/tasks.md 中标记为“已完成”任务的实际落实情况汇报如下：

  1. 关键偏离与未实现项（重点关注）


   * Task 2.3 & 4.10 (向量数据库集成):
       * 现状: sqlite-vec 向量扩展未实现。
       * 详情: 数据库 Schema 中 document_fragments 仅为普通表，embedding 以 TEXT 存储。相似度检索 (findSimilar) 实际上是在 Dart
         层加载所有数据到内存后，通过代码手动计算余弦相似度。这在大数据量下会产生严重的性能瓶颈，不符合“高性能向量扩展”的描述。
   * Task 4.11 & 4.12 (本地语音 STT/TTS):
       * 现状: 未原生集成，高度依赖外部服务。
       * 详情: WhisperSttService 和 LocalTtsService 并非集成 C++ 库或原生模型，而是硬编码调用
         http://localhost:8880。这意味着应用必须依赖一个单独运行的本地服务器才能工作。
       * VAD 偏离: 任务提到的 Silero VAD 仅实现为简单的音频振幅阈值判断 (db > -40)。
   * Task 9.5 (A2A mDNS 自动发现):
       * 现状: 未实现 (Stub)。
       * 详情: MdnsDiscoveryService 仅包含一个 StubMdnsDiscoveryService 类，其 discover() 方法直接返回 Stream.empty()。
   * Task 10.1 (本地 NER 模型 PII 检测):
       * 现状: 实现方案降级。
       * 详情: 任务要求“集成本地轻量 NER 模型”，实际实现 (PiiDetectionService) 仅使用了正则表达式 (RegExp) 来匹配手机号、身份证和银行卡。

  2. 部分实现与架构缺漏


   * Task 1.4 (Feature Flag): 基础设施极其简陋。仅在内存中维护一个 Map<AppFeatureModule, bool>，不支持持久化、远程配置或复杂的灰度策略。
   * Task 8.2 - 8.6 (后台任务引擎):
       * 移动端: 使用了 Workmanager 插件，但 backgroundCallbackDispatcher 核心回调函数目前是空桩 (Stub)，仅返回 true，未打通后台模型推理 (Task 8.6)。
       * 桌面端: 依赖 MethodChannel 调用原生代码，但 Dart 代码中已预警“Desktop platform channel not implemented”，原生层实现情况存疑。

  3. 实现质量优秀的模块（打通度高）


   * Task 5 (生成式 UI): 实现非常完整。UIComponentRegistry 拥有超过 1300
     行代码，定义了丰富的组件数据结构（产品、天气、日历、高铁、航班、地图等），且表现层与逻辑层对接良好。
   * Task 6 (Tool Bridge): 基于原生插件（device_calendar, flutter_contacts, url_launcher）实现了真正的设备能力调用，权限枚举和确认逻辑也已落地。
   * Task 7 (Skill Sandbox): 采用了巧妙的 webview_flutter 方案来运行 Pyodide (Python) 和 QuickJS，成功规避了 Dart 难以直接运行解释型语言沙箱的限制。
   * Task 10.5 (加密同步): 确实使用了 Argon2id 和 AES-256-GCM 算法（基于 cryptography 包），实现符合安全标准。
   * Task 11 (设置中心): 界面层极其丰富，几乎为所有后端服务都提供了对应的配置 UI，是目前完成度最高的模块之一。

  总结建议


  虽然项目在表现层 (Presentation) 和基础框架上表现出了极高的完成度，但在底层核心技术
  (Capability)（如向量扩展、本地模型集成、自动化协议发现）上存在明显的“降级实现”或“占位桩”。


  建议优先跟进:
   1. 集成真正的 sqlite-vec 或替代向量库以提升 RAG 性能。
   2. 补全 A2A mDNS 发现逻辑。
   3. 将本地语音服务的 HTTP 调用替换为真正的 Native 绑定或本地模型加载。


## Contributing

Contributions are welcome! Please feel free to submit a pull request or open an issue for any suggestions or improvements.

## License

This project is licensed under the MIT License. See the LICENSE file for more details.