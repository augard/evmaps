import SwiftUI
import UIKit
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate {
    var localClient: LocalCredentialClient! = nil

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Register background tasks
        BackgroundTaskManager.shared.registerBackgroundTasks()
        
        // Start the local credential server
        LocalCredentialServer.shared.start { success in
            print("AppDelegate: Server start success: \(success)")
        }
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Stop the local credential server
        LocalCredentialServer.shared.stop()
        BackgroundTaskManager.shared.cleanup()
        print("AppDelegate: Stopped local credential server")
    }
}
    
/// Modern background task manager using SwiftUI lifecycle
class BackgroundTaskManager: ObservableObject {
    static let shared = BackgroundTaskManager()
    
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private static let backgroundTaskIdentifier = "com.kiamaps.server-maintenance"
    
    private init() {}
    
    // MARK: - Background Support
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.backgroundTaskIdentifier, using: nil) { task in
            self.handleBackgroundServerMaintenance(task: task as! BGAppRefreshTask)
        }
        print("BackgroundTaskManager: Registered background task: \(Self.backgroundTaskIdentifier)")
    }
    
    func handleAppDidEnterBackground() {
        print("BackgroundTaskManager: App entered background, maintaining server")
        
        // Start background task to keep server running
        startBackgroundTask()
        
        // Schedule background app refresh
        scheduleBackgroundRefresh()
    }
    
    func handleAppWillEnterForeground() {
        print("BackgroundTaskManager: App entering foreground")
        
        // End background task if running
        endBackgroundTask()
        
        // Ensure server is running when returning to foreground
        if !LocalCredentialServer.shared.isRunning {
            LocalCredentialServer.shared.start()
        }
    }
    
    func cleanup() {
        endBackgroundTask()
    }
    
    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60) // Schedule for 1 minute from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("BackgroundTaskManager: Scheduled background refresh task")
        } catch {
            print("BackgroundTaskManager: Failed to schedule background refresh: \(error)")
        }
    }
    
    private func handleBackgroundServerMaintenance(task: BGAppRefreshTask) {
        print("BackgroundTaskManager: Handling background server maintenance")
        
        // Schedule next refresh
        scheduleBackgroundRefresh()
        
        task.expirationHandler = {
            print("BackgroundTaskManager: Background task expired")
            task.setTaskCompleted(success: false)
        }
        
        // Check and restart server if needed
        DispatchQueue.global(qos: .default).async {
            if !LocalCredentialServer.shared.isRunning {
                print("BackgroundTaskManager: Restarting server during background refresh")
                LocalCredentialServer.shared.start()
                
                // Wait a moment for server to start
                Thread.sleep(forTimeInterval: 2.0)
            }
            
            DispatchQueue.main.async {
                task.setTaskCompleted(success: LocalCredentialServer.shared.isRunning)
            }
        }
    }
    
    private func startBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "LocalServerMaintenance") {
            [weak self] in
            print("BackgroundTaskManager: Background task expired, ending task")
            self?.endBackgroundTask()
        }
        
        // Keep server running in background
        DispatchQueue.global(qos: .default).async {
            [weak self] in
            self?.maintainServerInBackground()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    private func maintainServerInBackground() {
        print("BackgroundTaskManager: Maintaining server in background")
        
        // Keep the server alive for as long as possible in background
        while backgroundTask != .invalid && UIApplication.shared.backgroundTimeRemaining > 5.0 {
            // Check server status periodically
            if !LocalCredentialServer.shared.isRunning {
                print("BackgroundTaskManager: Restarting server in background")
                LocalCredentialServer.shared.start()
            }
            
            // Sleep for a short interval
            Thread.sleep(forTimeInterval: 1.0)
        }
        
        print("BackgroundTaskManager: Background maintenance ending, time remaining: \(UIApplication.shared.backgroundTimeRemaining)")
    }
}

@main
struct Application: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var backgroundManager = BackgroundTaskManager.shared
    
    let configuration: AppConfiguration.Type = AppConfiguration.self
    @State private var navigationPath: [NavigationDestination] = []

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $navigationPath) {
                RootView(configuration: configuration, navigationPath: $navigationPath)
            }
            .environmentObject(backgroundManager)
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    /// Modern SwiftUI approach to handle app lifecycle changes
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            print("Application: Scene became active")
            backgroundManager.handleAppWillEnterForeground()
            
        case .inactive:
            print("Application: Scene became inactive")
            // Handle brief inactive state (e.g., incoming call, control center)
            
        case .background:
            print("Application: Scene entered background")
            backgroundManager.handleAppDidEnterBackground()
            
        @unknown default:
            print("Application: Unknown scene phase: \(phase)")
        }
    }
}
