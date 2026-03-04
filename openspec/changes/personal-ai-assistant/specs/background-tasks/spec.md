## ADDED Requirements

### Requirement: 多类型任务触发
系统 SHALL 支持 Cron 定时、相对时间、位置围栏进入/离开、数据阈值条件、外部 Webhook 事件、周期汇总六种后台任务触发类型。

#### Scenario: Cron 定时任务触发
- **WHEN** 系统时钟到达用户配置的 Cron 表达式指定时间
- **THEN** 系统 SHALL 唤起后台任务进程（iOS BGTaskScheduler / Android WorkManager），执行关联的 Agent 推理逻辑

#### Scenario: 位置围栏触发
- **WHEN** 设备进入用户设定的地理围栏区域
- **THEN** 系统 SHALL 在后台触发关联任务，发送系统通知，通知内容由本地 <4B 模型决策生成

#### Scenario: 条件触发任务
- **WHEN** 用户设定"当气温低于 10 度时提醒"，系统在后台检测到温度数据满足条件
- **THEN** 系统 SHALL 发送通知"当前气温 X 度，低于您设定的阈值"

### Requirement: 本地轻量模型后台推理
后台任务触发时 SHALL 使用本地 ≤4B 参数模型进行决策推理（≤1 秒），判断是否需要发送通知或执行操作。

#### Scenario: 后台推理决定静默跳过
- **WHEN** 周期汇总任务触发但当周无任何完成任务记录
- **THEN** 本地模型 SHALL 推理结论为"无内容可汇总，静默跳过"，不发送通知

### Requirement: 跨平台后台任务实现
系统 SHALL 在各平台使用原生最佳实践实现后台任务：iOS 使用 `BGTaskScheduler` + `BGProcessingTask`，Android 使用 `WorkManager` + `AlarmManager`，macOS/Windows 使用系统级 Cron / Task Scheduler。

#### Scenario: iOS 后台时间受限时降级
- **WHEN** iOS 系统限制后台执行时间导致任务未能完成
- **THEN** 系统 SHALL 降级为推送通知提醒，任务逻辑在用户下次打开 App 时补偿执行

#### Scenario: Android 引导加入电池优化白名单
- **WHEN** 首次创建定时任务且未在电池优化白名单时
- **THEN** 系统 SHALL 弹出引导页，说明原因并跳转到系统电池优化设置页面

### Requirement: 通知快捷操作
后台任务触发的系统通知 SHALL 支持内联快捷操作按钮（如"稍后提醒"、"已完成"、"立即处理"）。

#### Scenario: 通知中点击"稍后提醒"
- **WHEN** 用户在通知上点击"稍后提醒"
- **THEN** 系统 SHALL 将该任务推迟 1 小时后重新触发，无需打开 App

### Requirement: 任务管理 UI
系统 SHALL 提供任务列表界面，显示下次触发时间、执行历史日志，支持暂停/恢复/删除操作。

#### Scenario: 查看任务执行历史
- **WHEN** 用户点击某任务的"历史"入口
- **THEN** 系统 SHALL 显示最近 30 次触发记录，包含触发时间、推理结论、执行结果
