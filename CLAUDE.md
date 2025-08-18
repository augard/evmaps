# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a native iOS application that provides integration between Kia/Hyundai/Genesis electric vehicles and Apple Maps. The app allows users to view their vehicle's battery status and manage their vehicles through Apple's ecosystem, with Siri and Maps integration via Intents extensions.

## Build & Development Commands

### Build the Project
```bash
# Build all targets
xcodebuild -project KiaMaps.xcodeproj -scheme KiaMaps -configuration Debug build

# Build for specific target
xcodebuild -project KiaMaps.xcodeproj -target KiaMaps -configuration Debug build

# Clean build folder
xcodebuild -project KiaMaps.xcodeproj -scheme KiaMaps clean
```

### Run the Project with Manual Provisioning Profile (Porsche Configuration)

#### Prerequisites
1. Apple Developer Account with Porsche team access
2. Hand-created provisioning profile with Porsche group ID
3. Porsche API credentials configured

#### Setup Steps
1. **Open Project in Xcode**
   ```bash
   open KiaMaps.xcodeproj
   ```

2. **Configure Signing & Capabilities**
   - Select `KiaMaps` project in navigator
   - Go to `Signing & Capabilities` tab
   - **For Main App Target (KiaMaps)**:
     - Uncheck "Automatically manage signing"
     - Select your Porsche team from dropdown
     - Choose your hand-created provisioning profile
     - Set Bundle Identifier with Porsche group ID (e.g., `com.porsche.kiamaps`)
   - **For Extensions (KiaExtension, KiaExtensionUI)**:
     - Repeat above steps for each extension target
     - Use appropriate bundle identifiers:
       - `com.porsche.kiamaps.extension`
       - `com.porsche.kiamaps.extension-ui`

3. **App Groups Configuration**
   - Add App Groups capability to all targets
   - Use Porsche group ID: `group.com.porsche.kiamaps`
   - Ensure all targets use the same App Group ID for shared data

4. **Intents Configuration**
   - Verify Siri capability is enabled for main app
   - Ensure Intents Extension has proper entitlements
   - Check Maps integration entitlements

5. **Build and Run**
   - Select physical device (required for Intents)
   - Choose `KiaMaps` scheme
   - Build and run with Cmd+R

#### Troubleshooting Provisioning Issues
- **Profile mismatch**: Ensure provisioning profile includes your device UDID
- **Bundle ID conflicts**: Verify bundle IDs match those in provisioning profile
- **Entitlements**: Check that App Groups and Intents entitlements match profile
- **Team selection**: Confirm correct Porsche team is selected for all targets

#### Device Requirements
- Physical iOS device (Simulator doesn't support Intents properly)
- iOS 14.0+ for full Intents functionality
- Device must be registered in provisioning profile

### Project Targets
- **KiaMaps**: Main iOS application
- **KiaExtension**: Intents extension for Siri/Maps integration
- **KiaExtensionUI**: Intents UI extension for rich interactions

## Architecture Overview

The project follows a clean SwiftUI architecture with these key components:

### Core Structure
- **App Layer** (`KiaMaps/App/`): SwiftUI app entry point and main views
  - `AppDelegate.swift`: App lifecycle using SwiftUI @main
  - `MainView.swift`: Primary app UI with vehicle management
  - `VehicleStatusView.swift`: Vehicle status display

- **Core Layer** (`KiaMaps/Core/`): Business logic and data management
  - **Api** (`Core/Api/`): Network layer for vehicle API communication
    - `Api.swift`: Main API client with OAuth2 authentication flow
    - `ApiConfiguration.swift`: API endpoint configuration
    - `ApiEndpoints.swift`: API endpoint definitions
  - **Authorization** (`Core/Authorization/`): Authentication and security
    - `Authorization.swift`: Token management and storage
    - `Keychain.swift`: Secure credential storage
  - **Vehicle** (`Core/Vehicle/`): Vehicle-specific logic
    - `VehicleManager.swift`: Vehicle data caching and parameters
    - `KiaParameters.swift`, `PorscheParameters.swift`: Vehicle-specific configs
  - **Responses** (`Core/Responses/`): API response models and data structures

- **Extensions** (`KiaExtension/`, `KiaExtensionUI/`): Siri/Maps integration
  - `IntentHandler.swift`: Handles Siri shortcuts and Maps integration
  - `CarListHandler.swift`: Manages vehicle list for Siri
  - `GetCarPowerLevelStatusHandler.swift`: Provides battery status to Maps/Siri

### Key Design Patterns

1. **SwiftUI MVVM**: Uses SwiftUI's declarative UI with observable state management
2. **Async/Await**: Modern Swift concurrency for API calls
3. **OAuth2 Flow**: Complex authentication with multiple steps (login, device registration, token exchange)
4. **Caching Strategy**: Vehicle status cached with expiration via `VehicleManager`
5. **Multi-brand Support**: Configurable API endpoints for different vehicle brands

### Authentication Flow
The app implements a multi-step OAuth2 authentication:
1. Login page retrieval and form submission
2. Device ID registration with push notification setup
3. Authorization code exchange
4. Access token retrieval
5. User integration setup

### Data Flow
- Vehicle data flows from API → VehicleManager (caching) → SwiftUI Views
- Status updates trigger vehicle refresh via API
- Intents extensions access vehicle data for Siri/Maps integration

## Configuration

The app uses compile-time configuration via `AppConfiguration` protocol:
- API endpoints and credentials
- Vehicle VIN specification
- Brand-specific parameters

## No Testing Framework

This project does not currently have unit tests or a testing framework configured. When adding tests:
- Consider using XCTest framework
- Focus on API layer and VehicleManager logic
- Mock network requests for reliable testing

## Development Rules

### **Naming Conventions: Avoid "get" Prefix**
**IMPORTANT**: Follow consistent naming conventions for better code readability and Swift conventions.

```swift
// ✅ CORRECT: Network calls use "fetch" prefix
func fetchVehicleStatus(_ vehicleId: UUID) async throws -> VehicleStatus
func fetchUserProfile() async throws -> UserProfile
func fetchMQTTDeviceHost() async throws -> MQTTHostInfo

// ✅ CORRECT: Variables use descriptive names without "get"
var userProfile: UserProfile?
var vehicleStatus: VehicleStatus?
var connectionState: ConnectionState?

// ✅ CORRECT: Update/set operations use "update" prefix
func updateVehicleStatus(_ status: VehicleStatus)
func updateConnectionState(_ state: ConnectionState)

// ❌ INCORRECT: Don't use "get" prefix
func getVehicleStatus() // Use fetchVehicleStatus() instead
func getUserProfile()   // Use fetchUserProfile() instead
func getMQTTHost()      // Use fetchMQTTDeviceHost() instead

// ❌ INCORRECT: Don't use unnecessary prefixes for variables
var getUserProfile: UserProfile?     // Use userProfile instead
var getVehicleStatus: VehicleStatus? // Use vehicleStatus instead
```

**Naming Guidelines:**
- **Network calls**: Use `fetch` prefix for API calls that retrieve data
- **Variables**: Use descriptive names without prefixes when possible
- **Update operations**: Use `update` prefix for methods that modify existing data
- **Boolean properties**: Use `is`, `has`, `can`, `should` prefixes (e.g., `isConnected`, `hasError`)
- **Computed properties**: No prefix needed, use descriptive names (e.g., `connectionTimeString`, `statusColor`)

**Why avoid "get" prefix:**
- Swift conventions favor concise, descriptive names
- "get" is redundant - functions naturally "get" or return values
- Better readability: `fetchUserProfile()` vs `getUserProfile()`
- Consistency with Apple's naming conventions

### **Logging: Use AbstractLogger Instead of print**
**IMPORTANT**: Always use the `AbstractLogger` system for logging instead of `print` statements in production code.

```swift
// ✅ CORRECT: Use AbstractLogger for structured logging

// Import the logging system
import Foundation

// Use global convenience functions with appropriate categories
logDebug("Starting vehicle refresh", category: .vehicle)
logInfo("Vehicle status updated: \(vehicleId)", category: .vehicle)
logError("API request failed: \(error.localizedDescription)", category: .api)

// Alternative: Use the shared logger directly
SharedLogger.shared.logger.debug("MQTT connection established", category: .mqtt)
SharedLogger.shared.logger.warning("Battery level low", category: .vehicle)
SharedLogger.shared.logger.fault("Critical system failure", category: .app)

// ❌ INCORRECT: Don't use print in production code
print("Debug: Vehicle status updated") // Remove or replace with logDebug

// ❌ INCORRECT: Don't use direct os_log calls anymore
os_log(.debug, log: Logger.vehicle, "message") // Use logDebug instead
```

**Why use AbstractLogger:**
- Unified logging system across app and extensions
- Automatic remote logging to development server
- Built-in categorization with predefined categories
- Integration with both os_log and remote logging
- Better debugging capabilities during development
- Consistent logging format across the entire app

**Available Log Levels:**
- `logDebug()` - Detailed debugging information
- `logInfo()` - General informational messages  
- `logWarning()` - Warning conditions that should be noted
- `logError()` - Recoverable errors
- `logFault()` - Critical errors/system failures

**Available Categories:**
- `.api` - API calls and network requests
- `.auth` - Authentication and authorization
- `.server` - Local server operations
- `.app` - General app lifecycle and events
- `.ui` - User interface events
- `.bluetooth` - Bluetooth operations
- `.mqtt` - MQTT communication
- `.keychain` - Keychain and secure storage
- `.vehicle` - Vehicle data and operations
- `.ext` - Extension and Siri integration
- `.general` - Default category for uncategorized logs

**Usage Guidelines:**
- Always specify an appropriate category for better log organization
- Use descriptive messages that include context
- Include relevant data in log messages (user IDs, error codes, etc.)
- Use appropriate log levels - don't log everything as `.info`
- The system automatically handles file/function/line information

### **MANDATORY: Always Build After Code Changes**
**CRITICAL RULE**: After making ANY code changes, you MUST immediately build the project to verify compilation:

```bash
# Required command after every code change
xcodebuild -project KiaMaps.xcodeproj -scheme KiaMaps -configuration Debug build 2>&1 | grep -E "(error|warning|failed):" | grep -v "appintentsmetadataprocessor"
```

**Why this is mandatory:**
- Swift has strict type checking that catches errors at compile time
- Missing imports, wrong property names, and type mismatches must be fixed immediately
- Enum cases and struct properties change - compilation verifies correctness
- Icon names in `IconName` enum are limited - verify they exist before using
- API response structures may not match assumptions - build catches these issues

**Process:**
1. Make code changes
2. **IMMEDIATELY** run build command
3. Fix any errors before continuing
4. Only proceed to next changes after successful build

**This rule prevents:**
- Accumulating multiple compilation errors
- Wasting time on non-functional code
- Integration issues when merging changes
- Runtime crashes from basic type errors

## Key Files for Common Tasks

### Adding New Vehicle Brand Support
- Extend `VehicleParameters` protocol
- Add brand-specific parameters file (see `KiaParameters.swift`)
- Update `VehicleManager.vehicleParamter` switch statement
- Add API configuration for new endpoints
- **MUST BUILD** after each change

### Modifying API Endpoints
- Update `ApiEndpoints.swift` for new endpoints
- Modify `Api.swift` for new API methods
- Update response models in `Core/Responses/`
- **MUST BUILD** after each change

### Extending Siri Integration
- Add new intent definitions in `KiaExtension/IntentHandler.swift`
- Create corresponding handler files
- Update `KiaExtensionUI/` for rich UI experiences
- **MUST BUILD** after each change

### UI Changes
- Main app UI in `KiaMaps/App/MainView.swift`
- Vehicle status display in `KiaMaps/App/VehicleStatusView.swift`
- Reusable components in `KiaMaps/App/Views/`
- **Check IconName enum** in `KiaMaps/App/Views/DataRowView.swift` for available icons
- **MUST BUILD** after each change