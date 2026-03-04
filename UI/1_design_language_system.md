## 1. 设计语言与系统

### 1.1 设计理念

**"本地第一，无感智能"**——界面始终让用户感觉自己掌握主控权。智能行为应该感觉像是自然延伸，而不是神秘的黑盒。隐私保护不是限制，而是一种可感知的承诺。

整体风格定位：**工业精密感 + 温暖可亲性**。参考精密仪器的质感（分层、边界清晰、状态明确），同时保持对话的温度感。不是冷漠的工具，也不是过度拟人的玩具。

### 1.2 色彩系统

```
主色调（沉稳深蓝）
  --color-primary:        #1A2B4A   // 主要交互元素、强调文字
  --color-primary-light:  #2E4A7A   // hover 状态
  --color-primary-subtle: #EEF2F8   // 浅色背景强调

中性色阶（暖灰系，非纯灰）
  --color-bg-base:        #F7F6F4   // 主背景（微暖白）
  --color-bg-surface:     #FFFFFF   // 卡片/面板背景
  --color-bg-elevated:    #FDFCFB   // 浮层背景
  --color-border:         #E8E4DE   // 边框（暖米色调）
  --color-border-strong:  #C9C3BB   // 强调边框
  --color-text-primary:   #1C1A18   // 主文字（近黑暖色）
  --color-text-secondary: #6B6560   // 次要文字
  --color-text-muted:     #A09890   // 占位符/禁用

功能色
  --color-success:        #2D6A4F   // 成功/本地运行中
  --color-warning:        #B5621E   // 警告/注意
  --color-error:          #9B2335   // 错误/危险
  --color-info:           #1A5E8A   // 信息/云端

隐私标识色（专用）
  --color-local:          #2D6A4F   // 本地处理标记（绿色系）
  --color-cloud:          #1A5E8A   // 云端处理标记（蓝色系）

深色模式镜像（Dark Mode）
  --color-bg-base-dark:   #141210
  --color-bg-surface-dark:#1E1C19
  --color-text-primary-dark: #F0EDE8
  // ... 完整镜像，保持色温一致
```

### 1.3 字体系统

```
主标题 / 界面大标题
  字体族: "Instrument Serif" (衬线)
  用途: 欢迎屏、空态标题、设置页大标题
  
正文 / 对话内容
  字体族: "DM Sans" (无衬线)
  用途: 对话气泡、设置项文字、说明文字

等宽 / 技术内容  
  字体族: "JetBrains Mono"
  用途: 代码块、API Key 展示、Skill 名称、命令行输出

字号规格（移动端基准）
  --text-xs:   11px / 1.4  // 标签、状态标注
  --text-sm:   13px / 1.5  // 辅助文字、时间戳
  --text-base: 15px / 1.6  // 对话正文（适合长读）
  --text-md:   17px / 1.5  // 列表项主文字
  --text-lg:   20px / 1.4  // 小标题
  --text-xl:   24px / 1.3  // 页面标题
  --text-2xl:  32px / 1.2  // 大标题
```

### 1.4 间距与圆角系统

```
间距基准单位: 4px
  --space-1:  4px    --space-2:  8px    --space-3:  12px
  --space-4:  16px   --space-5:  20px   --space-6:  24px
  --space-8:  32px   --space-10: 40px   --space-12: 48px

圆角系统（偏小，保持精密感）
  --radius-sm:   4px   // 标签、角标
  --radius-md:   8px   // 输入框、小卡片
  --radius-lg:   12px  // 消息气泡、工具弹窗
  --radius-xl:   16px  // 主要卡片
  --radius-2xl:  24px  // 底部弹窗、大卡片
  --radius-full: 9999px // 头像、圆形按钮
```

### 1.5 阴影与层级系统

```
层级 1（轻微浮起，卡片）
  box-shadow: 0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04);

层级 2（中等浮起，下拉菜单）
  box-shadow: 0 4px 12px rgba(0,0,0,0.08), 0 2px 4px rgba(0,0,0,0.05);

层级 3（高浮起，模态框）
  box-shadow: 0 12px 40px rgba(0,0,0,0.12), 0 4px 12px rgba(0,0,0,0.06);

层级 4（最高，Toast / Tooltip）
  box-shadow: 0 20px 60px rgba(0,0,0,0.16);
```

### 1.6 动效原则

- **有意义的动效**：所有动效必须传递信息或引导注意力，不做纯装饰性炫技
- **方向感**：界面切换保持一致的空间方向（右进 = 深入，左出 = 返回，上出 = 关闭）
- **响应速度感**：输入到响应的视觉反馈 < 100ms，哪怕是占位动画
- **本地 vs 云端感**：本地处理用平静的脉冲动画；云端处理用更活跃的进度指示

```
缓动函数
  --ease-out:     cubic-bezier(0.0, 0.0, 0.2, 1)   // 进入动画
  --ease-in:      cubic-bezier(0.4, 0.0, 1, 1)     // 退出动画
  --ease-spring:  cubic-bezier(0.34, 1.56, 0.64, 1) // 弹性，用于确认/成功

时长规格
  --duration-fast:    120ms   // 微交互（hover、focus）
  --duration-normal:  220ms   // 元素进出
  --duration-slow:    380ms   // 页面切换
  --duration-xslow:   600ms   // 大面积布局变化
```

### 1.7 隐私状态视觉标识系统

这是本产品的核心差异化视觉元素，贯穿全局：

```
本地处理标识
  图标: 🔒 (shield.fill)
  颜色: --color-local (#2D6A4F)
  标签: "本地"
  背景: rgba(45, 106, 79, 0.08)

云端处理标识
  图标: ☁️ (cloud.fill)
  颜色: --color-cloud (#1A5E8A)
  标签: "云端"
  背景: rgba(26, 94, 138, 0.08)

混合处理标识
  图标: 🔀
  颜色: --color-warning (#B5621E)
  标签: "混合"
  说明: 点击可查看哪些部分走云端

出现位置：
  · 输入框附近（当前选择的处理方式）
  · 每条 AI 消息右下角（小角标）
  · 设置项标题右侧（说明该功能的处理位置）
```

---

