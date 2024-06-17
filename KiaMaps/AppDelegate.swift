import SwiftUI

@main
struct Application: App {
    let configuration: AppConfiguration.Type = AppConfiguration.self
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                MainView(configuration: configuration)
            }
        }
    }
}
