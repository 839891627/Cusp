import AppKit
import SwiftUI

@main
struct CuspApp: App {
    @StateObject private var viewModel: AppViewModel
    private let menuBarController: MenuBarStatusController

    init() {
        let viewModel = AppViewModel()
        _viewModel = StateObject(wrappedValue: viewModel)
        menuBarController = MenuBarStatusController(viewModel: viewModel)
    }

    var body: some Scene {
        WindowGroup {
            AppShellView(viewModel: viewModel)
                .frame(minWidth: 1040, minHeight: 760)
                .background(
                    MainWindowObserver { window in
                        AppVisibilityController.shared.registerMainWindow(window)
                    }
                )
                .onAppear {
                    menuBarController.startIfNeeded()
                }
                .task {
                    await viewModel.bootstrap()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

@MainActor
final class AppVisibilityController: NSObject, NSWindowDelegate {
    static let shared = AppVisibilityController()

    private weak var mainWindow: NSWindow?

    private override init() {
        super.init()
    }

    func registerMainWindow(_ window: NSWindow) {
        guard mainWindow !== window else {
            return
        }
        mainWindow = window
        window.delegate = self
    }

    func prepareToShowMainWindow() {
        _ = NSApplication.shared.setActivationPolicy(.regular)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        _ = NSApplication.shared.setActivationPolicy(.accessory)
        return false
    }

    func windowDidBecomeMain(_ notification: Notification) {
        _ = NSApplication.shared.setActivationPolicy(.regular)
    }
}

struct MainWindowObserver: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        TrackingView(onResolve: onResolve)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class TrackingView: NSView {
    private let onResolve: (NSWindow) -> Void

    init(onResolve: @escaping (NSWindow) -> Void) {
        self.onResolve = onResolve
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else {
            return
        }
        DispatchQueue.main.async { [weak self, weak window] in
            guard self != nil, let window else {
                return
            }
            self?.onResolve(window)
        }
    }
}
