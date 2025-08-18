import SwiftUI
import UIKit
import BackgroundTasks
import os.log

class AppDelegate: NSObject, UIApplicationDelegate {
    var localClient: LocalCredentialClient! = nil

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure shared logger for app
        AppLogger.configureSharedLogger()
        
        // Register background tasks
        BackgroundTaskManager.shared.registerBackgroundTasks()
        
        // Start Bluetooth scanning for vehicle head units
        BluetoothManager.shared.startScanning()
        
        // Start the local credential server
        LocalCredentialServer.shared.start { success in
            logInfo("Server start success: \(success ? "true" : "false")", category: .server)
        }
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Stop the local credential server
        LocalCredentialServer.shared.stop()
        BackgroundTaskManager.shared.cleanup()
        logInfo("Stopped local credential server", category: .server)
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
        logInfo("Registered background task: \(Self.backgroundTaskIdentifier)", category: .app)
    }
    
    func handleAppDidEnterBackground() {
        logInfo("App entered background, maintaining server", category: .app)
        
        // Start background task to keep server running
        startBackgroundTask()
        
        // Schedule background app refresh
        scheduleBackgroundRefresh()
    }
    
    func handleAppWillEnterForeground() {
        logInfo("App entering foreground", category: .app)
        
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
            logInfo("Scheduled background refresh task", category: .app)
        } catch {
            logError("Failed to schedule background refresh: \(error.localizedDescription)", category: .app)
        }
    }
    
    private func handleBackgroundServerMaintenance(task: BGAppRefreshTask) {
        logInfo("Handling background server maintenance", category: .app)
        
        // Schedule next refresh
        scheduleBackgroundRefresh()
        
        task.expirationHandler = {
            logInfo("Background task expired", category: .app)
            task.setTaskCompleted(success: false)
        }
        
        // Check and restart server if needed
        DispatchQueue.global(qos: .default).async {
            if !LocalCredentialServer.shared.isRunning {
                logInfo("Restarting server during background refresh", category: .app)
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
            logInfo("Background task expired, ending task", category: .app)
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
        logInfo("Maintaining server in background", category: .app)
        
        // Keep the server alive for as long as possible in background
        while backgroundTask != .invalid && UIApplication.shared.backgroundTimeRemaining > 5.0 {
            // Check server status periodically
            if !LocalCredentialServer.shared.isRunning {
                logInfo("Restarting server in background", category: .app)
                LocalCredentialServer.shared.start()
            }
            
            // Sleep for a short interval
            Thread.sleep(forTimeInterval: 1.0)
        }
        
        logInfo("Background maintenance ending, time remaining: \(UIApplication.shared.backgroundTimeRemaining)", category: .app)
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
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                EmptyView()
            } else {
                NavigationStack(path: $navigationPath) {
                    RootView(configuration: configuration, navigationPath: $navigationPath)
                }
                .environmentObject(backgroundManager)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    /// Modern SwiftUI approach to handle app lifecycle changes
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            logDebug("Scene became active", category: .app)
            backgroundManager.handleAppWillEnterForeground()
            
        case .inactive:
            logDebug("Scene became inactive", category: .app)
            // Handle brief inactive state (e.g., incoming call, control center)
            
        case .background:
            logDebug("Scene entered background", category: .app)
            backgroundManager.handleAppDidEnterBackground()
            
        @unknown default:
            logWarning("Unknown scene phase: \(String(describing: phase))", category: .app)
        }
    }
}
