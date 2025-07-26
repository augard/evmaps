import SwiftUI

@main
struct Application: App {
    let configuration: AppConfiguration.Type = AppConfiguration.self
    @State private var navigationPath: [NavigationDestination] = []

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $navigationPath) {
                RootView(configuration: configuration, navigationPath: $navigationPath)
            }
        }
    }
}
