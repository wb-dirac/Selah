## ADDED Requirements

### Requirement: 文字对话与 Markdown 渲染
系统 SHALL 在对话界面渲染 LLM 输出的 Markdown 内容，包括代码高亮、表格、数学公式（KaTeX）。

#### Scenario: 代码块高亮显示
- **WHEN** LLM 响应包含 Markdown 代码块（如 ` ```python ... ``` `）
- **THEN** 系统 SHALL 渲染带语言标注的高亮代码块，并提供一键复制按钮

#### Scenario: 重试分支（Re-generate）
- **WHEN** 用户长按某条助理消息并选择"重新生成"
- **THEN** 系统 SHALL 以相同 Prompt 重新请求 LLM，新响应作为该消息的分支存储，用户可左右切换分支

#### Scenario: 上下文压缩
- **WHEN** 对话 token 数超过当前模型上下文窗口的 80%
- **THEN** 系统 SHALL 自动对早期消息执行摘要压缩，并在 UI 以灰色分隔符提示"上下文已压缩"

### Requirement: 图片输入与处理
系统 SHALL 支持相机拍摄、相册选取、截图粘贴、桌面端拖拽上传四种图片输入方式，并优先在本地处理。

#### Scenario: 本地 OCR 识别
- **WHEN** 用户上传图片且请求包含文字识别需求
- **THEN** 系统 SHALL 先调用本地 OCR（Apple Vision / Google ML Kit）提取文字，将文字结果附加到 LLM 请求上下文

#### Scenario: 发送图片至云端前提示
- **WHEN** 用户上传图片且当前配置为云端多模态模型
- **THEN** 系统 SHALL 在发送前弹出提示："此图片将发送至[提供商名称]进行处理，是否继续？"，用户可选择仅使用本地处理

#### Scenario: 本地多模态降级
- **WHEN** 用户选择"仅本地处理"或无网络连接
- **THEN** 系统 SHALL 路由到本地 LLaVA / MiniCPM-V 模型，并在结果旁标注"本地模型，质量有限"

### Requirement: 文件输入与 RAG 处理
系统 SHALL 支持 PDF、Word（.docx）、Excel（.xlsx）、TXT、CSV、Markdown 文件作为对话上下文输入。

#### Scenario: 短文档直接注入上下文
- **WHEN** 用户上传文件且提取文本 token 数 ≤ 当前模型上下文窗口的 50%
- **THEN** 系统 SHALL 将全文提取文本直接注入 LLM 请求上下文

#### Scenario: 超长文档 RAG 分块检索
- **WHEN** 文件超过 50 页或提取 token 数超过上下文窗口 50%
- **THEN** 系统 SHALL 将文档分块嵌入本地 sqlite-vec 向量库，按用户问题检索最相关片段后注入上下文

#### Scenario: 文件内容不持久化
- **WHEN** 用户未明确请求保存文件内容
- **THEN** 系统 SHALL 在对话会话关闭时清除该文件的向量索引和提取文本缓存

### Requirement: 语音输入（普通模式）
系统 SHALL 支持本地 STT 语音输入流程：VAD 检测 → Whisper.cpp 转写 → 文字发送给 LLM。

#### Scenario: VAD 自动检测停止说话
- **WHEN** 用户开始说话后停顿超过 1.5 秒
- **THEN** 系统 SHALL 通过 Silero VAD 检测到语音结束，自动触发 STT 转写

#### Scenario: STT 完成后自动发送（可配置）
- **WHEN** STT 转写完成且用户已开启"自动发送"设置
- **THEN** 系统 SHALL 直接将转写文字发送给 LLM；若"自动发送"关闭，则文字填入输入框等待用户确认

### Requirement: 语音输出（TTS）
系统 SHALL 使用本地 TTS（Kokoro / Piper）将 LLM 文字响应转为语音播放，并支持音色选择。

#### Scenario: 流式 TTS 播放
- **WHEN** LLM 流式输出文字
- **THEN** 系统 SHALL 以句子为单位逐段送入 TTS 合成并立即播放，总延迟 < 1 秒（首句）

### Requirement: 实时全双工对话
系统 SHALL 支持通过 OpenAI Realtime API / Gemini Live / 豆包实时语音 API 进行端到端延迟 < 500ms 的实时对话，并支持打断（Barge-in）。

#### Scenario: 用户打断助理
- **WHEN** 助理正在播放语音时用户开始说话
- **THEN** 系统 SHALL 立即停止当前音频播放，切换为用户输入模式

#### Scenario: 对话结束后生成摘要
- **WHEN** 实时对话会话结束
- **THEN** 系统 SHALL 自动生成对话文字摘要并以普通消息形式存入本地对话历史
