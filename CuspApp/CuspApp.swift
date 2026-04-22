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
