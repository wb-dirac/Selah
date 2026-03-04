## ADDED Requirements

### Requirement: Anthropic Agent Skill 标准兼容
系统 SHALL 完整实现 Anthropic Agent Skill 三层加载标准：Level 1（元数据，应用启动时加载）、Level 2（指令正文，Skill 被触发时加载）、Level 3（资源与脚本，按需加载）。

#### Scenario: 应用启动加载 Skill 元数据
- **WHEN** 应用启动
- **THEN** 系统 SHALL 读取所有已安装 Skill 的 `SKILL.md` YAML frontmatter，将 `name` 和 `description` 注入 LLM 系统 Prompt，总消耗 ≤ 100 tokens/Skill

#### Scenario: Skill 被触发时加载指令正文
- **WHEN** LLM 判断需要调用某 Skill
- **THEN** 系统 SHALL 读取该 Skill 的 `SKILL.md` 正文（< 5k tokens），追加到当前请求上下文

#### Scenario: 脚本输出而非代码进入上下文
- **WHEN** Claude 通过 bash 指令调用 Skill 脚本
- **THEN** 系统 SHALL 在沙箱执行脚本，仅将脚本的 stdout 输出注入 LLM 上下文，脚本源码本身不进入上下文

### Requirement: SKILL.md 格式校验
系统 SHALL 验证 `SKILL.md` 的 YAML frontmatter 格式，包括 `name`（≤64字符，仅小写字母+数字+连字符，不含保留词 "anthropic" / "claude"）和 `description`（非空，≤1024字符）字段。

#### Scenario: name 包含大写字母时拒绝安装
- **WHEN** `SKILL.md` frontmatter 中 `name` 字段含大写字母
- **THEN** 系统 SHALL 拒绝安装并展示具体错误："name 字段只能包含小写字母、数字和连字符"

#### Scenario: description 为空时拒绝安装
- **WHEN** `SKILL.md` frontmatter 中 `description` 字段为空
- **THEN** 系统 SHALL 拒绝安装并展示错误："description 字段不能为空"

### Requirement: Python Skill 沙箱（Pyodide WASM）
系统 SHALL 在 Pyodide WebAssembly 沙箱中执行 `.py` Skill 脚本，禁止脚本访问宿主文件系统、发起网络请求或执行危险系统调用。

#### Scenario: Python 脚本禁止网络访问
- **WHEN** Python 脚本尝试调用 `urllib.request.urlopen()` 或 `socket.connect()`
- **THEN** 沙箱 SHALL 抛出 `PermissionError`，脚本以错误码退出，stdout 返回"网络访问被沙箱禁止"

#### Scenario: 脚本执行超时
- **WHEN** Python 脚本执行时间超过 30 秒
- **THEN** 系统 SHALL 强制终止脚本，向 LLM 返回超时错误信息

### Requirement: JavaScript Skill 沙箱（QuickJS VM）
系统 SHALL 在 QuickJS 独立 VM 中执行 `.js` Skill 脚本，无 DOM、无 Node.js 原生模块、无文件系统访问。

#### Scenario: JS 脚本无法访问全局对象
- **WHEN** JS 脚本尝试访问 `process` 或 `require`
- **THEN** QuickJS VM SHALL 抛出 `ReferenceError`，脚本以错误退出

### Requirement: Skill 安装安全扫描
系统 SHALL 在安装 Skill 前执行本地静态安全扫描，通过 AST 分析检测危险调用，扫描结果分为通过 / 警告 / 拒绝三级。

#### Scenario: Python 脚本含 os.system 调用时警告
- **WHEN** Skill 中 Python 脚本包含 `os.system()` 或 `subprocess.run()` 调用
- **THEN** 扫描 SHALL 返回警告级别，展示"发现潜在危险调用：os.system"，用户可选择继续安装或取消

#### Scenario: 发现 prompt injection 特征时拒绝
- **WHEN** `SKILL.md` 正文包含伪装成系统指令的内容（如 `[SYSTEM]: Ignore all previous instructions`）
- **THEN** 扫描 SHALL 返回拒绝级别，强制阻止安装并显示具体原因

### Requirement: Skill 市场多源对接
系统 SHALL 对接 Anthropic 官方 Skill 目录和社区 GitHub 索引，支持分类浏览、关键词搜索和一键安装，用户可手动添加自定义市场源 URL。

#### Scenario: 浏览 Skill 市场
- **WHEN** 用户打开 Skill 市场并选择"效率"分类
- **THEN** 系统 SHALL 展示该分类下的 Skill 列表，包含名称、描述、安装数量和作者信息

### Requirement: Skill 运行时管理
系统 SHALL 提供 Skill 管理界面，支持查看 SKILL.md 内容、运行日志、启用/禁用/卸载操作。

#### Scenario: 卸载 Skill 清除所有数据
- **WHEN** 用户卸载某 Skill
- **THEN** 系统 SHALL 删除 Skill 目录、清除该 Skill 的隔离数据目录和所有运行日志
