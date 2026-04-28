# UXPilot 导出包精简输入说明

> 目的：把 `uxpilot-export-1777270218469` 中可用页面筛出来，形成稳定输入，避免 AI 被噪音页面误导。

## 建议保留（主输入）

以下 4 个页面可作为本轮重设计主参考：

- `uxpilot-export-1777270218469/13-Proxy Client - Overview.html`
- `uxpilot-export-1777270218469/14-Proxy Client - Nodes & Strateg.html`
- `uxpilot-export-1777270218469/15-Proxy Client - Subscriptions.html`
- `uxpilot-export-1777270218469/16-Proxy Client - Settings.html`

这些页面在信息密度、布局完整性、macOS 视觉语言一致性上明显更好，可用于提炼组件与交互框架。

## 建议降权或剔除（噪音输入）

以下页面包含明显模板复用痕迹（如大量 `Welcome to Cusp`），容易污染结果：

- `uxpilot-export-1777270218469/1-Cusp Proxy - Welcome.html`
- `uxpilot-export-1777270218469/4-Cusp Proxy - Profiles.html`
- `uxpilot-export-1777270218469/5-Cusp Proxy - Nodes.html`
- `uxpilot-export-1777270218469/6-Cusp Proxy - Rules (规则管理).html`
- `uxpilot-export-1777270218469/8-Cusp Proxy - Settings.html`
- `uxpilot-export-1777270218469/9-Cusp Proxy - Settings.html`
- `uxpilot-export-1777270218469/10-Cusp Proxy - Onboarding - Step.html`
- `uxpilot-export-1777270218469/12-Cusp Proxy - Sign In.html`

## 重复稿处理

- `11-Proxy Client - Overview.html` 与 `13-Proxy Client - Overview.html` 为同类稿，建议保留 `13`，将 `11` 作为弱参考或忽略。

## 本轮缺口（需要 AI 补全设计）

当前高质量页面对以下模块覆盖不足，需要在下一轮明确要求补齐：

- `Routes`（连接路由）
- `Rules`（规则管理）
- `Logs`（运行日志）

## 给 AI 的输入边界（防跑偏）

给其他 AI 工具时，建议附加以下约束：

1. 仅将上述 4 个主页面作为视觉与结构参考。
2. 禁止回退到 Welcome/Onboarding 模板风格。
3. 必须完整输出 `Overview / Routes / Strategy / Nodes / Rules / Subscriptions / Logs / Settings`。
4. 必须兼容 EN/简中长度差异，并保持术语与 `Docs/UI-Terminology.md` 一致。
5. 页面产出需能映射到 SwiftUI 组件，不接受纯概念图。

