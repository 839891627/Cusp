import Foundation

public struct TrialSetupStep: Equatable, Sendable {
    public let title: String
    public let detail: String

    public init(title: String, detail: String) {
        self.title = title
        self.detail = detail
    }
}

public struct TrialSetupGuide: Equatable, Sendable {
    public let title: String
    public let steps: [TrialSetupStep]

    public init(title: String, steps: [TrialSetupStep]) {
        self.title = title
        self.steps = steps
    }

    public var isComplete: Bool {
        title == "Ready To Launch"
    }
}

public enum TrialSetupGuideBuilder {
    public static func build(from report: MVPReadinessReport) -> TrialSetupGuide {
        if report.isReady {
            return TrialSetupGuide(
                title: "Ready To Launch",
                steps: [
                    TrialSetupStep(
                        title: "Run The App",
                        detail: "Launch Cusp, click Connect, and approve any system prompt needed to change proxy settings."
                    )
                ]
            )
        }

        var steps: [TrialSetupStep] = []
        let failingTitles = Set(report.blockingItems.map { $0.title })

        if failingTitles.contains("System Proxy Control") {
            steps.append(
                TrialSetupStep(
                    title: "Verify Network Services",
                    detail: "Make sure Wi-Fi or Ethernet is enabled in macOS System Settings so Cusp can switch proxy settings for an active service."
                )
            )
        }

        if failingTitles.contains("Bundled mihomo") {
            steps.append(
                TrialSetupStep(
                    title: "Bundle mihomo",
                    detail: "Place an executable mihomo binary at Resources/mihomo/mihomo and rebuild so it is copied into the app bundle."
                )
            )
        }

        if failingTitles.contains("Server Configuration") {
            steps.append(
                TrialSetupStep(
                    title: "Import A Node",
                    detail: "Paste a valid ss:// URI, save it, and confirm the node summary appears before connecting."
                )
            )
        }

        if steps.isEmpty {
            steps.append(
                TrialSetupStep(
                    title: "Review Setup",
                    detail: "Relaunch Cusp after fixing the blocked items, then retry the readiness checks."
                )
            )
        }

        return TrialSetupGuide(
            title: "Setup Guide",
            steps: steps
        )
    }
}
