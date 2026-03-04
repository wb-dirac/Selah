## ADDED Requirements

### Requirement: 四级权限分级模型
系统 SHALL 对所有工具按风险等级分类为 L0（无需授权）、L1（首次授权）、L2（每次确认）、L3（明确指令），并依级别执行对应的用户确认流程。

#### Scenario: L0 工具静默执行
- **WHEN** Agent 调用 L0 工具（如写入剪贴板、URL Scheme 跳转）
- **THEN** 系统 SHALL 直接执行，无需弹窗，但在对话界面显示"正在执行：[工具名]"提示

#### Scenario: L1 工具首次授权
- **WHEN** Agent 首次调用 L1 工具（如读取联系人）
- **THEN** 系统 SHALL 弹出授权对话框说明用途，用户授权后记录权限状态，后续调用同类工具不再弹窗

#### Scenario: L2 工具每次确认
- **WHEN** Agent 请求调用 L2 工具（如发送邮件草稿）
- **THEN** 系统 SHALL 每次弹出确认对话框，显示将要执行的操作详情，用户点击确认后执行

#### Scenario: L3 工具显示完整操作预览
- **WHEN** Agent 请求调用 L3 工具（如拨打电话）
- **THEN** 系统 SHALL 显示包含完整操作参数的预览界面，用户须主动点击"确认执行"方可继续

### Requirement: 通信类工具
系统 SHALL 实现读取联系人（L1）、搜索联系人（L1）、创建联系人（L2）、发送邮件草稿（L2）、发送短信（L2，移动端）、拨打电话（L3，移动端）。

#### Scenario: 搜索联系人返回结果
- **WHEN** Agent 调用 `search_contact(query="张总")`
- **THEN** 系统 SHALL 在本地通讯录检索匹配联系人，以 `contact_card` Schema 返回前 5 条结果

### Requirement: 日历与提醒工具
系统 SHALL 实现读取日历事件（L1）、创建日历事件（L2）、修改/删除事件（L2）、创建提醒（L2）。

#### Scenario: 创建日历事件
- **WHEN** Agent 调用 `create_calendar_event(title, start, end, location)`
- **THEN** 系统 SHALL 显示事件摘要确认弹窗，用户确认后写入系统日历，返回成功状态

#### Scenario: 修改事件显示前后对比
- **WHEN** Agent 请求修改已有日历事件
- **THEN** 系统 SHALL 展示"修改前 / 修改后"对比视图，用户确认后执行修改

### Requirement: 位置与地图工具
系统 SHALL 实现获取当前位置（L1，仅在对话期间使用）、地点搜索（L0）、唤起地图导航 App（L0）。

#### Scenario: 位置数据不持久化
- **WHEN** Agent 调用 `get_current_location()`
- **THEN** 系统 SHALL 获取坐标后仅在当次对话会话内存中使用，对话结束后立即清除，不写入数据库

### Requirement: 第三方 App 唤起
系统 SHALL 支持通过 URL Scheme / Universal Link / Intent 唤起高德、百度、Google Maps、微信、支付宝、钉钉、飞书等外部 App。

#### Scenario: 唤起前显示提示
- **WHEN** Agent 请求唤起外部 App
- **THEN** 系统 SHALL 在执行跳转前显示"即将打开 [App 名称]"toast，用户可在 500ms 内点击取消

### Requirement: 工具调用透明度与审计
系统 SHALL 在对话界面实时展示正在调用的工具名称，并在设置中提供工具调用历史日志。

#### Scenario: 实时显示工具调用状态
- **WHEN** Agent 执行工具调用
- **THEN** 对话界面 SHALL 在助理消息气泡下方显示"正在调用：[工具名]…"指示，调用完成后消失

#### Scenario: 撤销工具权限
- **WHEN** 用户在设置-权限管理页点击某工具的"撤销授权"
- **THEN** 系统 SHALL 立即撤销该工具的 L1 授权记录，下次调用时重新触发首次授权流程
