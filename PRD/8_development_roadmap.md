## 8. 开发路线图

### Phase 1：MVP（预计 8 周）

**目标**：核心对话体验可用，支持多 LLM 接入，基础工具集

- [ ] Flutter 项目框架搭建（iOS / Android / macOS）
- [ ] LLM Gateway：支持 OpenAI Compatible / Anthropic / 本地 Ollama
- [ ] API Key 加密配置 UI
- [ ] 基础文字对话界面（Markdown 渲染）
- [ ] 图片输入：OCR + 发送至多模态 LLM
- [ ] 基础工具：日历读写、联系人搜索、邮件草稿
- [ ] 本地 SQLite 加密存储
- [ ] 基础生成式 UI：product_card / calendar_event / contact_card

**Phase 1 交付物**：可用的 MVP，内测版本发布

### Phase 2：核心体验完善（预计 8 周）

**目标**：语音能力、完整工具集、Skill 沙箱、定时任务、跨设备同步

- [ ] 语音输入（语音消息直传多模态 LLM，音频本地保存）
- [ ] 语音输出（供应商 TTS，语音输入后自动播放回复）
- [ ] 完整工具集（地图唤起、App 跳转、文件处理）
- [ ] Anthropic Agent Skill 标准支持（Manifest 解析、Tool 调用、沙箱运行）
- [ ] Skill 市场对接（对接已有开放市场，支持列表/搜索/安装）
- [ ] Skill 安装安全扫描（AST 静态分析 + 权限校验）
- [ ] 后台定时任务（Cron + 位置触发）
- [ ] 生成式 UI 扩展（map_preview / flight_card / weather_card）
- [ ] 权限管理 UI（工具授权、Skill 权限）
- [ ] **GitHub Gist 跨设备同步**（OAuth 授权 + 端对端加密）

### Phase 3：生态与协作（预计 8 周）

**目标**：A2A 协议、实时语音、桌面端、Agent 发现目录接入

- [ ] A2A 协议实现（Host + Remote 双角色）
- [ ] Agent 服务发现（mDNS + 手动添加 + 接入已有 A2A 公开目录）
- [ ] 实时全双工语音（OpenAI Realtime API 接入）
- [ ] Windows 端适配
- [ ] PII 检测与脱敏
- [ ] Skill 市场多源聚合（支持用户添加自定义市场源）

### Phase 4：智能化与优化（持续迭代）

- [ ] 本地模型智能路由与成本优化
- [ ] 用户画像本地学习（个性化偏好）
- [ ] 跨 Agent 复杂工作流编排
- [ ] Skill 沙箱性能优化与资源限制精细化调整

---

