# Cusp 无开发者账号安装与排障指南

本文适用于没有 Apple Developer 账号、使用 unsigned/ad-hoc 包分发的场景。

## 1) 安装前说明

- 安装包是 unsigned、未 notarized。
- `spctl` 校验不通过是预期行为，不代表包本身一定损坏。
- 首次安装可能需要手动放行应用。

## 2) 下载后校验（推荐）

在发布页下载后，先在终端进入下载目录并校验：

```bash
shasum -a 256 -c SHA256SUMS.txt
```

如果输出 `OK`，说明文件和发布时一致。

## 3) Gatekeeper 放行

如果双击无法打开，可按顺序尝试：

1. Finder 中右键 `Cusp.app`，选择“打开”并确认。
2. 打开“系统设置 -> 隐私与安全性”，在底部点击“仍要打开”。
3. 如仍被阻止，可在终端移除 quarantine 标记：

```bash
xattr -dr com.apple.quarantine /Applications/Cusp.app
```

## 4) 首次启动建议

1. 先导入节点配置，不要立刻开机自启动。
2. 首次点击连接时，若出现系统网络权限提示，先允许。
3. 如果连接失败，优先用菜单中的“复制系统代理命令”进行 `sudo` 手动恢复或切换。

## 5) 崩溃/强退后的网络恢复

如果崩溃后出现“全局网络异常”或“浏览器打不开”：

1. 重新启动 Cusp。
2. 在总览页使用 `Restore` 按钮恢复残留代理。
3. 若应用无法启动，使用菜单复制出的 `networksetup` 命令在终端执行。

## 6) 常见问题

### Q1: `spctl -a -vv Cusp.app` 显示拒绝

这是 unsigned 分发下的正常现象，不作为唯一故障依据。

### Q2: 连接时报权限错误（authorization/administrator）

说明当前账户无法直接修改系统代理。先走 `sudo networksetup ...` 兜底，再确认系统设置中的网络权限策略。

### Q3: 启动时报 mihomo 校验失败

应用会校验内置 mihomo 的 SHA256。请重新下载发布包，或核对发布页的 `SHA256SUMS.txt`。

## 7) 适用边界

这个分发方式适合本机自用、小范围团队内分发、技术用户环境。
若需要面向大规模普通用户分发，建议迁移到 Developer ID 签名 + notarization 路线。
