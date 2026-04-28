# Cusp 项目结构梳理与重构建议（2026-04-22）

## 1. 当前结构（As-Is）

```text
CuspApp/
  Services/      # 本地代理、系统代理切换、环境检查
  UI/            # 基础 UI 组件
  ViewModels/    # 当前主要为 AppViewModel
  Views/         # 主窗口页面与菜单栏视图逻辑

Sources/CuspShared/
  解析器、配置构建器、运行时模型、共享存储与网络辅助

Tests/CuspSharedTests/
  Shared 层单元测试（覆盖较完整）
```

## 2. 主要问题

1. `AppViewModel.swift` 体量过大（约 3514 行），承担过多领域职责。
2. 菜单栏控制逻辑与主状态耦合，后续功能扩展易引发回归。
3. 业务模型层次混杂：UI 状态、运行态、持久化态在同一层集中管理。
4. 文档与工程治理（开源相关）文件此前缺失，协作门槛偏高。

## 3. 重构优先级建议

### P0（建议尽快）

1. 拆分 `AppViewModel` 为多域子模块：
   - `SubscriptionDomainStore`
   - `NodeDomainStore`
   - `RuleDomainStore`
   - `RuntimeDomainStore`
   - `SettingsDomainStore`
2. 新增 `AppStateStore` 作为聚合层，页面仅订阅自己关心的切片状态。
3. 菜单栏提取为独立读模型：`MenuBarSnapshotProvider`，避免直接读取全量 ViewModel。

### P1（体验与演进）

1. `Views/` 按页面域拆目录：`Overview/`, `Strategy/`, `Rules/`, `Subscriptions/`, `Settings/`, `Logs/`。
2. `Services/` 再细分 `Runtime/`, `System/`, `Persistence/`。
3. 统一错误模型与可观测日志结构（例如 `AppError` + `DiagnosticsEvent`）。

### P2（长期）

1. 抽出可复用 UI 设计系统模块（tokens + reusable components）。
2. 建立集成测试（订阅导入 -> 配置生成 -> 运行态切换的关键路径）。

## 4. 建议的目标结构（To-Be）

```text
CuspApp/
  App/
    CuspApp.swift
    AppStateStore.swift
  Domains/
    Runtime/
    Subscription/
    Node/
    Rule/
    Settings/
  Services/
    Runtime/
    System/
    Persistence/
  Views/
    Overview/
    Strategy/
    Rules/
    Subscriptions/
    Logs/
    Settings/
  UI/
    Components/
    Theme/

Sources/CuspShared/
  Parsing/
  Config/
  Runtime/
  Models/
  Storage/
```

## 5. 实施建议

1. 先做“无行为变化”的拆分（extract type / move file）。
2. 每拆一块补对应测试，确保 `swift test` 持续通过。
3. 菜单栏和主窗口状态读取改为统一快照，减少闪烁和状态竞争。
