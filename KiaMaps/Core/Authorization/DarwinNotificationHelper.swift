//
//  DarwinNotificationHelper.swift
//  KiaMaps
//
//  Created by Claude on 21.01.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import Foundation
import CoreFoundation

/// Helper class for Darwin notifications to enable IPC between app and extensions
enum DarwinNotificationHelper {
    /// Notification names for credential-related events
    enum NotificationName {
        static let credentialsUpdated = "com.kiamaps.auth.credentials.updated"
        static let credentialsCleared = "com.kiamaps.auth.credentials.cleared"
    }
    
    /// Posts a Darwin notification with the given name
    /// - Parameter name: The notification name to post
    static func post(name: String) {
        let notificationName = name as CFString
        
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(notificationName),
            nil,
            nil,
            true
        )
    }
    
    /// Observes Darwin notifications with the given name
    /// - Parameters:
    ///   - name: The notification name to observe
    ///   - callback: The callback to execute when notification is received
    static func observe(name: String, callback: @escaping () -> Void) {
        let notificationName = name as CFString
        
        // Create a context to hold the callback
        let context = UnsafeMutableRawPointer(Unmanaged.passRetained(CallbackWrapper(callback)).toOpaque())
        
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            context,
            { (_, observer, _, _, _) in
                guard let observer = observer else { return }
                let wrapper = Unmanaged<CallbackWrapper>.fromOpaque(observer).takeUnretainedValue()
                wrapper.callback()
            },
            notificationName,
            nil,
            .deliverImmediately
        )
    }
    
    /// Removes observation for Darwin notifications with the given name
    /// - Parameter name: The notification name to stop observing
    static func removeObserver(name: String) {
        let notificationName = name as CFString
        
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            CFNotificationName(notificationName),
            nil
        )
    }
}

/// Wrapper class to hold callback for Darwin notifications
private class CallbackWrapper {
    let callback: () -> Void
    
    init(_ callback: @escaping () -> Void) {
        self.callback = callback
    }
}