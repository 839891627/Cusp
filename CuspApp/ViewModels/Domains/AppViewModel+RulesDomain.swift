import AppKit
import Foundation
import UniformTypeIdentifiers

extension AppViewModel {
    func addRoutingRule() {
        let matcher = ruleMatcherInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !matcher.isEmpty else {
            lastActionMessage = nil
            lastErrorMessage = selectedLanguage == .simplifiedChinese
                ? "请填写规则匹配值。"
                : "Please provide a rule matcher."
            return
        }

        routingRules.append(
            RoutingRule(
                type: selectedRuleType,
                matcher: matcher,
                action: selectedRuleAction
            )
        )
        ruleMatcherInput = ""
        persistCurrentSubscriptionCatalog()
        lastActionMessage = selectedLanguage == .simplifiedChinese
            ? "已添加规则。"
            : "Rule added."
        lastErrorMessage = nil
        restartRuntimeIfNeededAfterRuleChange()
    }

    func removeRoutingRule(id: String) {
        routingRules.removeAll { $0.id == id }
        persistCurrentSubscriptionCatalog()
        restartRuntimeIfNeededAfterRuleChange()
    }

    func moveRoutingRule(id: String, by offset: Int) {
        guard let index = routingRules.firstIndex(where: { $0.id == id }) else {
            return
        }
        let target = index + offset
        guard routingRules.indices.contains(target) else {
            return
        }
        routingRules.swapAt(index, target)
        persistCurrentSubscriptionCatalog()
        restartRuntimeIfNeededAfterRuleChange()
    }

    func resetRoutingRulesToPreset() {
        routingRules = RoutingRulePreset.commonMVP
        persistCurrentSubscriptionCatalog()
        lastActionMessage = selectedLanguage == .simplifiedChinese
            ? "已恢复内置规则。"
            : "Restored built-in rules."
        lastErrorMessage = nil
        restartRuntimeIfNeededAfterRuleChange()
    }

    func applyRuleTemplate(_ template: RuleTemplateKind) {
        routingRules = RuleTemplateCatalog.rules(for: template)
        persistCurrentSubscriptionCatalog()
        lastActionMessage = selectedLanguage == .simplifiedChinese
            ? "已应用规则模板：\(displayName(for: template))。"
            : "Applied rule template: \(displayName(for: template))."
        lastErrorMessage = nil
        restartRuntimeIfNeededAfterRuleChange()
    }

    func importRulesFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "conf"),
            UTType.yaml,
            UTType(filenameExtension: "yml"),
            UTType.plainText
        ].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = selectedLanguage == .simplifiedChinese ? "导入" : "Import"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let parsed = RoutingRuleCodec.parse(from: text)
            guard !parsed.isEmpty else {
                throw NSError(domain: "CuspRules", code: 1, userInfo: [NSLocalizedDescriptionKey: "No parseable rules"])
            }
            routingRules = parsed
            persistCurrentSubscriptionCatalog()
            lastActionMessage = selectedLanguage == .simplifiedChinese
                ? "已导入 \(parsed.count) 条规则。"
                : "Imported \(parsed.count) rules."
            lastErrorMessage = nil
            restartRuntimeIfNeededAfterRuleChange()
        } catch {
            lastActionMessage = nil
            lastErrorMessage = selectedLanguage == .simplifiedChinese
                ? "规则导入失败。"
                : "Failed to import rules."
        }
    }

    func exportRules(asYAML: Bool) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = asYAML ? "cusp-rules.yaml" : "cusp-rules.conf"
        panel.allowedContentTypes = asYAML
            ? [UTType.yaml]
            : [UTType(filenameExtension: "conf"), UTType.plainText].compactMap { $0 }
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let payload = asYAML ? RoutingRuleCodec.exportYAML(routingRules) : RoutingRuleCodec.exportConf(routingRules)
        do {
            try payload.write(to: url, atomically: true, encoding: .utf8)
            lastActionMessage = selectedLanguage == .simplifiedChinese
                ? "规则已导出。"
                : "Rules exported."
            lastErrorMessage = nil
        } catch {
            lastActionMessage = nil
            lastErrorMessage = selectedLanguage == .simplifiedChinese
                ? "规则导出失败。"
                : "Failed to export rules."
        }
    }
}
