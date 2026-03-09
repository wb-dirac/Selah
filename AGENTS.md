# AGENTS.md
本文件供 Coding Agent 快速了解项目工作规范

## 关键文档
执行任务时，涉及相关文档必读
### [完整规范索引](CODING_STANDARDS/index.md)
  1. [1_project_structure.md](CODING_STANDARDS/1_project_structure.md) - Project Structure Standards
  2. [2_general_coding_rules.md](CODING_STANDARDS/2_general_coding_rules.md) - General Coding Rules
  3. [3_flutter_dart_standards.md](CODING_STANDARDS/3_flutter_dart_standards.md) - Flutter / Dart Specific Standards
  4. [4_security_privacy.md](CODING_STANDARDS/4_security_privacy.md) - Security and Privacy Coding Standards
  5. [5_database_operations.md](CODING_STANDARDS/5_database_operations.md) - Local Database Operation Standards
  6. [6_llm_gateway.md](CODING_STANDARDS/6_llm_gateway.md) - LLM Gateway Coding Standards
  7. [7_skill_sandbox.md](CODING_STANDARDS/7_skill_sandbox.md) - Skill Sandbox Coding Standards
  8. [8_a2a_protocol.md](CODING_STANDARDS/8_a2a_protocol.md) - A2A Protocol Coding Standards
  9. [9_tool_bridge.md](CODING_STANDARDS/9_tool_bridge.md) - Tool Bridge Coding Standards
  10. [10_background_tasks.md](CODING_STANDARDS/10_background_tasks.md) - Background Tasks Coding Standards
  11. [11_generative_ui.md](CODING_STANDARDS/11_generative_ui.md) - Generative UI Coding Standards
  12. [12_testing.md](CODING_STANDARDS/12_testing.md) - Testing Standards
  13. [13_verification_checklist.md](CODING_STANDARDS/13_verification_checklist.md) - Verifiable Mechanisms: Automatic Check List
  14. [14_cicd_pipeline.md](CODING_STANDARDS/14_cicd_pipeline.md) - Verifiable Mechanisms: CI/CD Pipeline
  15. [15_code_review.md](CODING_STANDARDS/15_code_review.md) - Verifiable Mechanisms: Code Review Protocol
  16. [16_agent_behavior.md](CODING_STANDARDS/16_agent_behavior.md) - Coding Agent Behavior Constraints
### [产品需求索引](PRD/index.md)
  1. [1_product_overview.md](PRD/1_product_overview.md) - Product Overview
  2. [2_target_users_scenarios.md](PRD/2_target_users_scenarios.md) - Target Users and Use Cases
  3. [3_product_architecture.md](PRD/3_product_architecture.md) - Product Architecture Overview
  4. [4_functional_requirements.md](PRD/4_functional_requirements.md) - Functional Module Detailed Requirements
  5. [5_non_functional_requirements.md](PRD/5_non_functional_requirements.md) - Non-Functional Requirements
  6. [6_technology_selection.md](PRD/6_technology_selection.md) - Technology Selection
  7. [7_cloud_dependency_analysis.md](PRD/7_cloud_dependency_analysis.md) - Cloud Dependency Boundary Analysis
  8. [8_development_roadmap.md](PRD/8_development_roadmap.md) - Development Roadmap
  9. [9_risks_mitigation.md](PRD/9_risks_mitigation.md) - Risks and Mitigation Measures
  10. [10_appendix.md](PRD/10_appendix.md) - Appendix
### [UI/UX 规范索引](UI/index.md)
  1. [1_design_language_system.md](1_design_language_system.md) - Design Language and System
  2. [2_navigation_information_architecture.md](2_navigation_information_architecture.md) - Navigation Structure and Information Architecture
  3. [3_main_conversation_interface.md](3_main_conversation_interface.md) - Main Conversation Interface
  4. [4_multimodal_input_toolbar.md](4_multimodal_input_toolbar.md) - Multimodal Input Toolbar
  5. [5_real_time_voice_interface.md](5_real_time_voice_interface.md) - Real-time Voice Conversation Interface
  6. [6_generative_ui_card_library.md](6_generative_ui_card_library.md) - Generative UI Card Component Library
  7. [7_llm_configuration_interface.md](7_llm_configuration_interface.md) - LLM Configuration Interface
  8. [8_agent_skill_market_management.md](8_agent_skill_market_management.md) - Agent Skill Market and Management
  9. [9_background_task_management.md](9_background_task_management.md) - Background Task Management Interface
  10. [10_a2a_agent_discovery.md](10_a2a_agent_discovery.md) - A2A Agent Service Discovery Interface
  11. [11_privacy_security_settings.md](11_privacy_security_settings.md) - Privacy and Security Settings
  12. [12_cross_device_sync_settings.md](12_cross_device_sync_settings.md) - Cross-Device Synchronization Settings
  13. [13_tool_permissions_management.md](13_tool_permissions_management.md) - Tool Permissions Management
  14. [14_notifications_shortcuts.md](14_notifications_shortcuts.md) - Notifications and Shortcuts
  15. [15_desktop_adaptation_differences.md](15_desktop_adaptation_differences.md) - Desktop Adaptation Differences
  16. [16_empty_exception_states.md](16_empty_exception_states.md) - Empty States and Exception States
  17. [17_accessibility_design.md](17_accessibility_design.md) - Accessibility Design Standards

## 技术栈速查
- 框架：Flutter（Dart）
- 状态管理：Riverpod
- 数据库：SQLite + SQLCipher
- 加密：AES-256-GCM + Argon2id

## 提交前必做
dart tool/verify.dart

## 高风险目录（改动需特别谨慎）
- lib/core/crypto/        # 加密核心
- lib/core/keychain/      # 密钥存储
- lib/features/privacy/   # PII 检测
- lib/features/skill_sandbox/  # 沙箱安全

## 禁止的代码模式（速查）
1. 不用 print()，用 AppLogger
2. API Key 只存 KeyChain，不存 SharedPreferences
3. SQL 只用参数化，不拼字符串
4. HTTP 必须 HTTPS
5. 不留空 catch 块
6. Skill 沙箱无网络访问

## 测试位置
- test/unit/          单元测试
- test/security/      安全测试（阻断级）
- test/integration/   集成测试
- test/performance/   性能基准
- test/golden/        视觉回归