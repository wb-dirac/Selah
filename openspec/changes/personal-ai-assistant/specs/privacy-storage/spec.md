## ADDED Requirements

### Requirement: API Key 硬件级加密存储
系统 SHALL 使用 iOS/macOS KeyChain、Android KeyStore、Windows DPAPI 存储所有 API Key，严禁任何明文 Key 写入文件系统或日志。

#### Scenario: 日志系统脱敏 API Key
- **WHEN** 任意模块记录包含 API Key 的日志
- **THEN** 日志系统 SHALL 将 Key 自动替换为 `[REDACTED]`，不得输出 Key 的任何字符

#### Scenario: API Key 永不参与跨设备同步
- **WHEN** 用户开启 GitHub Gist 跨设备同步
- **THEN** 系统 SHALL 明确排除所有 API Key 字段，同步内容不含任何 API Key

### Requirement: 对话历史 SQLCipher 加密存储
对话历史 SHALL 使用 SQLCipher（AES-256-GCM）加密存储在本地 SQLite 数据库，密钥由 OS 安全密钥存储管理。

#### Scenario: 数据库文件无法在应用外读取
- **WHEN** 攻击者直接访问设备文件系统中的 SQLite 文件
- **THEN** 文件内容 SHALL 为 AES-256 加密密文，无有效密钥无法解密读取

#### Scenario: 对话历史默认保留 90 天
- **WHEN** 对话消息创建时间超过用户设定的保留期限（默认 90 天）
- **THEN** 系统 SHALL 在下次清理任务时自动删除过期记录

### Requirement: 位置数据不持久化
系统 SHALL 不将位置数据写入任何持久化存储，位置信息仅在当前对话会话的内存中使用。

#### Scenario: 对话结束后位置数据清除
- **WHEN** 用户关闭对话或会话超时
- **THEN** 系统 SHALL 清除该会话中持有的所有位置坐标数据

### Requirement: PII 检测与脱敏
系统 SHALL 内置本地轻量 NER 模型，在对话发送至云端 LLM 前自动检测手机号、身份证号、银行卡号等 PII，并支持用户配置"发送前确认"模式。

#### Scenario: 检测到 PII 时高亮提示
- **WHEN** 用户输入或 Prompt 包含疑似手机号（如 138xxxxxxxx）
- **THEN** 系统 SHALL 在 Prompt 预览中高亮标注该内容，提示"检测到可能的手机号，是否在发送前脱敏？"

#### Scenario: 联系人姓名默认替换为代号
- **WHEN** 对话中出现已在通讯录中的联系人姓名且目标为云端 LLM
- **THEN** 系统 SHALL 默认将姓名替换为"联系人A"等代号，替换规则在会话中保持一致

### Requirement: 数据生命周期管理
系统 SHALL 提供一键清除所有本地数据功能，支持用户自定义对话历史保留天数。

#### Scenario: 一键清除所有数据
- **WHEN** 用户在设置中点击"清除所有本地数据"并二次确认
- **THEN** 系统 SHALL 删除 SQLite 数据库、向量库、Skill 数据目录、缓存，并清除 OS KeyChain 中的所有 Key

### Requirement: GitHub Gist 跨设备端对端加密同步（Phase 2）
系统 SHALL 支持用户使用自有 GitHub 账号，以 Argon2id 从用户 passphrase 派生密钥，对同步数据进行 AES-256-GCM 加密后存储至私有 Gist，仅申请 `gist` OAuth 权限范围。

#### Scenario: API Key 字段永不出现在 Gist 中
- **WHEN** 用户触发同步
- **THEN** 系统 SHALL 验证同步数据集中不含任何 API Key 字段，若意外包含则中止同步并报错

#### Scenario: 同步冲突展示 diff 后用户决策
- **WHEN** 本地数据与 Gist 远端数据存在冲突
- **THEN** 系统 SHALL 展示差异摘要，提供"保留本地"/"使用远端"选项，默认不自动覆盖

#### Scenario: passphrase 不存储在任何云端
- **WHEN** 用户设置同步 passphrase
- **THEN** 系统 SHALL 仅将派生的加密密钥临时存储在 OS KeyChain，passphrase 本身在设置完成后立即从内存清除，不上传至任何服务器
