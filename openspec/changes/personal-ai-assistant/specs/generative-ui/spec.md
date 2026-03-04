## ADDED Requirements

### Requirement: LLM 输出 UI Schema 解析
系统 SHALL 解析 LLM 响应中的 JSON UI Schema 块，并将其路由至对应的 Flutter 组件渲染器。

#### Scenario: 解析并渲染商品卡片
- **WHEN** LLM 响应包含 `"ui_type": "product_card"` 的 JSON Schema 块
- **THEN** 系统 SHALL 提取 Schema，通过 UIComponentRegistry 匹配 `product_card` 渲染器，渲染带图片、价格、操作按钮的原生卡片

#### Scenario: 未知组件类型降级
- **WHEN** LLM 输出的 `ui_type` 在 Registry 中无对应渲染器
- **THEN** 系统 SHALL 将该 JSON Schema 以格式化代码块形式展示，不崩溃

### Requirement: 内置组件库
系统 SHALL 包含以下 10 种内置组件类型：`product_card`、`map_preview`、`contact_card`、`calendar_event`、`flight_card`、`train_card`、`weather_card`、`code_block`、`task_list`、`price_chart`。

#### Scenario: 日历事件卡片添加到系统日历
- **WHEN** 用户点击 `calendar_event` 卡片上的"添加到日历"按钮
- **THEN** 系统 SHALL 触发 Tool Bridge 的日历创建工具，完成后在卡片上标记"已添加"

#### Scenario: 地图卡片唤起导航
- **WHEN** 用户点击 `map_preview` 卡片上的"导航"按钮
- **THEN** 系统 SHALL 通过 Tool Bridge URL Scheme 唤起用户已安装的地图 App（高德 / 百度 / Google Maps）

#### Scenario: 代码块运行
- **WHEN** `code_block` 组件语言为 Python 且用户点击"运行"
- **THEN** 系统 SHALL 在 Skill 沙箱（Pyodide）中执行代码，将 stdout 输出显示在卡片内联区域

### Requirement: 组件交互事件触发 Agent 任务
系统 SHALL 支持卡片上的操作按钮触发新的 Agent 任务（`agent_task` 类型 action）。

#### Scenario: 点击"比较价格"触发 Agent 任务
- **WHEN** 用户点击 `product_card` 上 action 为 `agent_task`，task 为 `compare_price` 的按钮
- **THEN** 系统 SHALL 以该产品信息为上下文发起新的 Agent 推理流程，返回价格对比卡片

### Requirement: 组件扩展注册 API
系统 SHALL 提供插件可调用的 UIComponentRegistry API，允许 Skill 注册新的组件类型。

#### Scenario: Skill 注册自定义组件
- **WHEN** Skill 加载时调用 `UIComponentRegistry.register(definition)` 并传入合法的 `UIComponentDefinition`
- **THEN** 系统 SHALL 将该组件类型存入 Registry，后续 LLM 响应中出现该 `ui_type` 时正常渲染

### Requirement: 响应式布局与深色模式
所有生成式 UI 组件 SHALL 在手机、平板、桌面三种布局下自适应渲染，并自动跟随系统深色模式。

#### Scenario: 平板端宽屏布局
- **WHEN** 设备宽度 ≥ 600dp 且显示 `product_card`
- **THEN** 系统 SHALL 以双列网格形式渲染多个卡片，充分利用横向空间

#### Scenario: 深色模式自动适配
- **WHEN** 系统切换到深色模式
- **THEN** 所有已渲染卡片 SHALL 立即更新配色至深色主题，无需重新加载
