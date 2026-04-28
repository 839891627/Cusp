# Cusp UI 重设计 Phase 2 Prompt（补齐缺口版）

> 用法：直接复制给任意 AI 设计工具（ChatGPT / Claude / v0 / UXPilot / 其他），用于在现有方案基础上补齐缺失模块并统一全局。

你是资深 macOS 产品设计师 + 交互设计师。请基于我已有导出稿，完成 Cusp UI 的第二轮重设计。

## 已有输入（仅允许参考这些页面）

- `13-Proxy Client - Overview.html`
- `14-Proxy Client - Nodes & Strateg.html`
- `15-Proxy Client - Subscriptions.html`
- `16-Proxy Client - Settings.html`

不要参考 Welcome/Onboarding/Sign In 类页面，不要复用其布局风格。

## 产品背景

- Cusp 是 macOS 原生代理客户端（SwiftUI）
- 产品目标：清晰、稳定、高频操作效率
- 核心能力：订阅管理、模式切换（Direct/Global/Rules）、节点/策略切换、规则管理、日志诊断、菜单栏快捷操作
- 双语：英文 + 简体中文

## 本轮核心任务

在保留现有主风格的前提下，**补齐并统一**以下模块：

1. `Routes`（连接路由）
2. `Rules`（规则管理）
3. `Logs`（运行日志）

并确保与 `Overview / Strategy / Nodes / Subscriptions / Settings` 在视觉与交互上一致。

## 强约束（必须遵守）

1. 禁止生成 Welcome/Onboarding 风格页面。
2. 全量覆盖 8 个模块：
   - Overview
   - Routes
   - Strategy
   - Nodes
   - Rules
   - Subscriptions
   - Logs
   - Settings
3. 所有文案支持 EN + 简中长度变化，不允许布局破版。
4. 术语必须与以下映射一致（如有冲突，以此为准）：
   - Overview=总览
   - Routes=连接路由
   - Strategy=策略
   - Nodes=节点
   - Subscriptions=订阅
   - Logs=日志
   - Settings=设置
5. 方案必须可落地到 SwiftUI（组件化、可实现、状态完整）。

## 重点设计要求

### A) Overview（强化状态可读性）

- 3 秒内可读：连接状态、当前模式、当前节点/策略、异常状态
- 提供快捷动作：连接/断开、切模式、切节点、刷新订阅

### B) Routes（新增完整页面）

- 清晰显示路由决策链路：命中条件 -> 规则来源 -> 最终动作（DIRECT/PROXY/REJECT）
- 支持按域名/IP/应用筛选查看历史命中
- 提供可追溯信息（命中时间、规则 ID、优先级）

### C) Rules（从“可编辑”升级到“可管理”）

- 规则列表支持：排序、启停、优先级调整、冲突提示
- 支持导入/导出（YAML/CONF）和重置预设
- 对危险操作（重置/覆盖）给确认与回滚提示

### D) Logs（新增高可用诊断页）

- 分级展示：Info / Warning / Error
- 支持过滤、搜索、复制、清空
- 错误日志需包含“建议动作”（下一步怎么修复）

## 输出格式（严格按顺序）

1. 新版 IA（导航结构与模块关系）
2. 8 个模块的关键用户流程图（简版即可）
3. 页面线框（至少 Overview/Routes/Rules/Logs/Settings）
4. 高保真视觉规范（Light + Dark）
5. 组件系统（组件清单 + 交互状态 + 可复用规则）
6. Design Tokens（颜色/字号/间距/圆角/阴影）
7. SwiftUI 落地映射建议（组件命名、拆分粒度、优先级）
8. 分期方案（P0: 必做, P1: 优化）

## 验收标准

- 用户能快速判断当前是否正常工作
- 高频任务步骤显著减少
- Routes / Rules / Logs 可独立承担诊断与恢复任务
- 全局视觉统一，组件语义一致
- 输出可直接进入工程实现，而非概念展示

如果信息不足，请先提出你最关键的 5 个问题；然后在“默认假设”下继续给出完整方案，不要中断。

