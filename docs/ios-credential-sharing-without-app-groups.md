# iOS Credential Sharing Without App Groups: Unorthodox Solutions

*Research conducted on 2025-01-21*

## Overview

This document outlines unorthodox solutions for sharing credentials between iOS applications and their extensions when standard methods (App Groups, iCloud, UserDefaults) are unavailable due to entitlement restrictions.

## Problem Statement

The KiaMaps iOS application needs to share OAuth2 credentials and authentication state between:
- Main app (`KiaMaps`)
- Intents extension (`KiaExtension`) 
- Intents UI extension (`KiaExtensionUI`)

Standard solutions are unavailable because the app cannot use App Groups entitlements due to provisioning profile restrictions.

## Research Findings

### Standard Methods (Unavailable)
- **App Groups + UserDefaults**: Requires `com.apple.security.application-groups` entitlement
- **App Groups + Shared Container**: Same entitlement requirement
- **iCloud KeyValue Store**: Requires iCloud entitlements
- **NSUbiquitousDocument**: Requires iCloud Document entitlements

### Alternative Solutions Discovered

## Solution 1: Keychain Access Groups (Recommended)

**Status**: ✅ Most viable - separate from App Groups entitlement

Keychain access groups are distinct from App Groups and can share credentials without requiring the `application-groups` entitlement.

### Implementation

```swift
// Entitlements configuration
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.yourcompany.shared</string>
</array>

// Swift implementation
class KeychainCredentialSharing {
    private let accessGroup = "com.yourcompany.shared"
    
    func saveCredential(_ credential: String, for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup as String: accessGroup,
            kSecValueData as String: credential.data(using: .utf8)!
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func retrieveCredential(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup as String: accessGroup,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let credential = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return credential
    }
}
```

### Advantages
- No App Groups entitlement required
- Secure credential storage
- Native iOS security integration
- Works across all iOS versions

### Disadvantages
- Keychain-specific (credentials only)
- Requires careful entitlement configuration

## Solution 2: Darwin Notifications + File System

**Status**: ⚠️ Experimental - combining IPC signaling with file-based storage

Uses Darwin notifications for inter-process communication combined with Documents directory file sharing.

### Implementation

```swift
// Darwin Notification Helper
class DarwinNotificationHelper {
    static func post(name: String) {
        let notificationName = CFStringCreateWithCString(kCFAllocatorDefault, name, kCFStringEncodingUTF8)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(notificationName!),
            nil, nil, true
        )
    }
    
    static func observe(name: String, callback: @escaping () -> Void) {
        let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let notificationName = CFStringCreateWithCString(kCFAllocatorDefault, name, kCFStringEncodingUTF8)
        
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { _, _, _, _, _ in callback() },
            CFNotificationName(notificationName!),
            nil,
            .deliverImmediately
        )
    }
}

// File-based credential sharing
class FileBasedCredentialSharing {
    private let fileName = ".credentials_shared"
    
    private var documentsPath: URL? {
        FileManager.default.urls(for: .documentDirectory, 
                                in: .userDomainMask).first
    }
    
    func saveCredentials(_ credentials: [String: String]) {
        guard let path = documentsPath?.appendingPathComponent(fileName) else { return }
        
        do {
            let data = try JSONEncoder().encode(credentials)
            try data.write(to: path)
            
            // Signal that credentials are updated
            DarwinNotificationHelper.post(name: "com.yourapp.credentials.updated")
        } catch {
            print("Failed to save credentials: \(error)")
        }
    }
    
    func loadCredentials() -> [String: String]? {
        guard let path = documentsPath?.appendingPathComponent(fileName) else { return nil }
        
        do {
            let data = try Data(contentsOf: path)
            return try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            return nil
        }
    }
}
```

### Advantages
- Real-time notification capability
- Can share complex data structures
- No entitlement requirements

### Disadvantages
- File system access may be sandboxed differently
- Potential race conditions
- Less secure than Keychain

## Solution 3: URL Scheme + Pasteboard Hack

**Status**: 🔶 Hacky - temporary pasteboard usage with URL scheme triggering

### Implementation

```swift
class URLSchemeCredentialSharing {
    private let customScheme = "kiamaps-credentials"
    
    // In main app
    func shareCredentialsThroughURLScheme(_ credentials: String) {
        // Temporarily put encrypted credentials in pasteboard
        let encrypted = encrypt(credentials)
        UIPasteboard.general.string = encrypted
        
        // Trigger extension through URL scheme
        if let url = URL(string: "\(customScheme)://fetch-credentials") {
            UIApplication.shared.open(url)
        }
        
        // Clear pasteboard after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            UIPasteboard.general.string = ""
        }
    }
    
    // In extension
    func retrieveCredentialsFromPasteboard() -> String? {
        guard let encrypted = UIPasteboard.general.string else { return nil }
        return decrypt(encrypted)
    }
    
    private func encrypt(_ string: String) -> String {
        // Implement encryption (AES, etc.)
        return string
    }
    
    private func decrypt(_ string: String) -> String {
        // Implement decryption
        return string
    }
}
```

### Advantages
- No entitlements required
- Works across processes

### Disadvantages
- Security concerns (pasteboard exposure)
- User experience disruption
- Timing-dependent
- Unreliable

## Solution 4: Network Loopback Communication

**Status**: 🔶 Creative - localhost HTTP server for IPC

### Implementation

```swift
class NetworkLoopbackSharing {
    private let port: UInt16 = 8080
    
    // In main app - start server
    func startCredentialServer() {
        let server = HTTPServer()
        server.listenPort = port
        
        server["/credentials"] = { request in
            let credentials = getStoredCredentials()
            return .ok(.text(encrypt(credentials)))
        }
        
        try? server.start()
    }
    
    // In extension - fetch credentials
    func fetchCredentials(completion: @escaping (String?) -> Void) {
        let url = URL(string: "http://localhost:\(port)/credentials")!
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data,
                  let encrypted = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            
            completion(decrypt(encrypted))
        }.resume()
    }
}
```

### Advantages
- Standard HTTP protocols
- Can handle complex data

### Disadvantages
- Network permissions required
- Resource intensive
- App Review concerns
- Port conflicts possible

## Solution 5: SQLite with File Coordination

**Status**: ⚠️ Advanced - shared database with proper locking

### Implementation

```swift
import SQLite3

class SQLiteCredentialSharing {
    private let dbPath: String
    
    init() {
        let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        dbPath = "\(documents)/shared_credentials.db"
        setupDatabase()
    }
    
    private func setupDatabase() {
        var db: OpaquePointer?
        
        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            let createTable = """
                CREATE TABLE IF NOT EXISTS credentials (
                    key TEXT PRIMARY KEY,
                    value TEXT,
                    timestamp INTEGER
                )
            """
            
            if sqlite3_exec(db, createTable, nil, nil, nil) != SQLITE_OK {
                print("Error creating table")
            }
        }
        
        sqlite3_close(db)
    }
    
    func saveCredential(key: String, value: String) {
        var db: OpaquePointer?
        
        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            let insertSQL = "INSERT OR REPLACE INTO credentials (key, value, timestamp) VALUES (?, ?, ?)"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, key, -1, nil)
                sqlite3_bind_text(statement, 2, value, -1, nil)
                sqlite3_bind_int64(statement, 3, Int64(Date().timeIntervalSince1970))
                
                sqlite3_step(statement)
            }
            
            sqlite3_finalize(statement)
        }
        
        sqlite3_close(db)
    }
    
    func retrieveCredential(key: String) -> String? {
        var db: OpaquePointer?
        var result: String?
        
        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            let querySQL = "SELECT value FROM credentials WHERE key = ?"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, key, -1, nil)
                
                if sqlite3_step(statement) == SQLITE_ROW {
                    let queryResultCol1 = sqlite3_column_text(statement, 0)
                    result = String(cString: queryResultCol1!)
                }
            }
            
            sqlite3_finalize(statement)
        }
        
        sqlite3_close(db)
        return result
    }
}
```

### Advantages
- Robust data storage
- ACID compliance
- Multiple reader support

### Disadvantages
- Complex implementation
- File coordination needed
- Potential corruption risks

## Recommendation for KiaMaps

### Primary Solution: Keychain Access Groups

Implement **Solution 1 (Keychain Access Groups)** as the main credential sharing mechanism because:

1. **Security**: Native iOS security integration
2. **Reliability**: Apple-sanctioned approach
3. **Simplicity**: Minimal implementation required
4. **No entitlement conflicts**: Separate from App Groups
5. **OAuth2 focused**: Perfect for storing tokens and auth state

### Secondary Solution: Darwin Notifications for Synchronization

Combine with **Solution 2 (Darwin Notifications)** for real-time sync signals:

```swift
// Example integration
class KiaMapsCredentialManager {
    private let keychain = KeychainCredentialSharing()
    
    func saveOAuth2Token(_ token: String) {
        keychain.saveCredential(token, for: "oauth2_token")
        DarwinNotificationHelper.post(name: "com.kiamaps.auth.updated")
    }
    
    func observeAuthUpdates() {
        DarwinNotificationHelper.observe(name: "com.kiamaps.auth.updated") {
            // Refresh token in extension
            self.refreshAuthState()
        }
    }
}
```

## Implementation Steps for KiaMaps

1. **Update Entitlements**:
   - Add `keychain-access-groups` to all targets
   - Use team ID prefix: `$(AppIdentifierPrefix)com.kiamaps.shared`

2. **Modify Authorization.swift**:
   - Replace current token storage with Keychain access group
   - Add Darwin notification posting on auth state changes

3. **Update Extensions**:
   - Add keychain access to `IntentHandler.swift`
   - Implement Darwin notification observers
   - Share auth state between main app and extensions

4. **Test Scenarios**:
   - Fresh app install and authentication
   - Extension access to credentials
   - Main app auth state updates
   - Extension credential refresh

## Security Considerations

- **Encryption**: Add additional encryption layer for sensitive tokens
- **Access Control**: Use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- **Key Rotation**: Implement periodic credential refresh
- **Cleanup**: Clear credentials on logout/uninstall

## Limitations and Risks

1. **Keychain Persistence**: Credentials survive app deletion
2. **Team ID Dependency**: Requires consistent team ID across updates
3. **Platform Restrictions**: iOS-specific solution
4. **Review Process**: Ensure App Store compliance

## Alternative Fallbacks

If keychain access groups fail:
- Fall back to Solution 2 (File + Darwin notifications)
- Implement manual credential entry in extensions
- Use network-based credential refresh

## Conclusion

The keychain access groups approach provides the most robust and Apple-compliant solution for sharing OAuth2 credentials between the KiaMaps application and its extensions without requiring App Groups entitlements. This solution maintains security standards while enabling the necessary Siri and Maps integration functionality.