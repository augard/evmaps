# KiaMaps Extension Communication Testing

This document describes how to test the local server communication between the main KiaMaps app and its extensions.

## Overview

Phase 6 implemented a local server-based communication system to replace keychain sharing between the main app and extensions. The system consists of:

1. **LocalCredentialServer** - Runs in the main app on localhost:8765
2. **ExtensionCredentialClient** - Used by extensions to fetch credentials from the server
3. **Password protection** - Server requires a compile-time password for security

## Testing the Implementation

### Manual Testing

1. **Start the main app**:
   ```bash
   # Build and run the main app
   xcodebuild -project KiaMaps.xcodeproj -scheme KiaMaps -configuration Debug
   ```

2. **Run the test script**:
   ```bash
   # Test server communication
   ./test_local_server.swift
   ```

3. **Expected output**:
   ```
   🧪 Testing KiaMaps Local Credential Server...
   🔄 Connecting to local server...
   ✅ Connected to server
   ✅ Received credentials:
      Access Token: eyJhbGciO...
      Device ID: 12345678-1234-1234-1234-123456789012
      Expires In: 3600
      Selected VIN: KMHL14JA5PA123456
      Timestamp: 2025-01-26 15:30:45 +0000
   🎉 Local server communication test PASSED
   ```

### Automated Testing

The project includes XCTest unit tests:

1. **LocalCredentialServerTests** - Tests server functionality
2. **ExtensionIntegrationTests** - Tests end-to-end communication

To run tests (when test target is configured):
```bash
xcodebuild test -project KiaMaps.xcodeproj -scheme KiaMapsTests
```

## Test Coverage

### ✅ Completed Tests

1. **Server Lifecycle**
   - Server starts and stops without errors
   - Server handles restart gracefully

2. **Authentication**
   - Server validates client passwords
   - Server rejects unauthorized requests
   - Credentials are properly transmitted

3. **Multiple Clients**
   - Server handles concurrent requests
   - Multiple extensions can access credentials simultaneously

4. **Error Handling**
   - Server handles missing credentials gracefully
   - Client times out when server unavailable
   - Network errors are handled properly

5. **Data Integrity**
   - Authorization data is transmitted correctly
   - Selected vehicle VIN is shared properly
   - Timestamps are included in responses

### Security Features

1. **Password Protection**
   - Compile-time password via environment variable `KIAMAPS_SERVER_PASSWORD`
   - Fallback password: `KiaMapsSecurePassword2025`
   - All requests must include valid password

2. **Local-Only Access**
   - Server only binds to localhost (127.0.0.1)
   - No external network access possible

3. **No Keychain in Extensions**
   - Extensions completely removed from keychain access
   - All credentials come from main app via local server

## Troubleshooting

### Server Not Responding
1. Ensure main app is running
2. Check that server started successfully (look for "Started local credential server" in logs)
3. Verify no firewall blocking localhost:8765

### Authentication Failures
1. Check password configuration in environment variables
2. Ensure extensions use correct `ExtensionCredentialClient`
3. Verify server logs for password validation errors

### Missing Credentials
1. Ensure user is logged in to main app
2. Check that credentials are stored in main app
3. Verify `SharedVehicleManager.shared.selectedVehicleVIN` is set

## Implementation Details

### Server Configuration
- **Port**: 8765 (hardcoded, could be made configurable)
- **Protocol**: TCP with JSON messaging
- **Timeout**: 3 seconds for extension requests
- **Queue**: Dedicated dispatch queue for network operations

### Client Configuration
- **Timeout**: 3 seconds maximum wait time
- **Retry**: No automatic retry (extensions should handle failures gracefully)
- **Fallback**: No keychain fallback (extensions are server-only)

### Message Format
```json
// Request
{
  "password": "KiaMapsSecurePassword2025",
  "extensionIdentifier": "KiaExtension"
}

// Response
{
  "authorization": {
    "stamp": "encoded-stamp",
    "deviceId": "uuid-string",
    "accessToken": "bearer-token",
    "expiresIn": 3600,
    "refreshToken": "refresh-token",
    "isCcuCCS2Supported": true
  },
  "selectedVIN": "KMHL14JA5PA123456",
  "timestamp": "2025-01-26T15:30:45Z"
}
```

## Migration Notes

Phase 6 represents a complete migration from keychain-based credential sharing to local server communication:

- **Before**: Extensions accessed shared keychain directly
- **After**: Extensions request credentials from main app server
- **Benefits**: Better security, no keychain conflicts, centralized credential management
- **Compatibility**: Graceful fallback during transition period (now removed)