# Kia\Hyundai\Genesis Apple Maps Integration

This application is adding support for your EV to Apple Maps. Currently it's working just for cars from Europe.

## Building with Xcode and Manual Provisioning Profile (Porsche Configuration)

### Prerequisites
1. Apple Developer Account with access to create App IDs
2. Kia\Hyundai\Genesis API credentials configured
3. Physical iOS or Simulator device

### Initial Developer Portal Setup

#### 1. Create Wildcard App ID
1. Go to [developer.apple.com](https://developer.apple.com)
2. Sign in and navigate to Certificates, Identifiers & Profiles
3. Click Identifiers → + button to create new App ID
4. Select "App IDs" and click Continue
5. Enter:
   - Description: "Porsche Wildcard Apps"
   - Bundle ID: Select "Wildcard"
   - Enter: `com.porsche.*`
6. Enable required capabilities:
   - App Groups
   - SiriKit
7. Click Continue and Register

#### 2. Create Provisioning Profile
After creating the wildcard App ID:
1. Navigate to Profiles → + button
2. Select "iOS App Development" or "Ad Hoc" (for testing)
3. Select your wildcard App ID (`com.porsche.*`)
4. Select your development certificate
5. Select devices for testing
6. Name it (e.g., "Porsche Wildcard Development")
7. Download the provisioning profile

### Setup Steps

#### 1. Configure Signing Settings
Copy and customize the signing configuration:
```bash
cp Config/Signing.xcconfig.template Config/Signing.xcconfig
```

Edit `Config/Signing.xcconfig` and update:
- `DEVELOPMENT_TEAM`: Your Apple Developer Team ID
- `PROVISIONING_PROFILE_SPECIFIER`: Your provisioning profile name
- `EXTENSION_PROVISIONING_PROFILE_SPECIFIER`: Your extension profile name
- `EXTENSION_UI_PROVISIONING_PROFILE_SPECIFIER`: Your UI extension profile name

Example:
```
DEVELOPMENT_TEAM = ABC123DEF4
PROVISIONING_PROFILE_SPECIFIER = Porsche Wildcard Development
```

#### 2. Open Project in Xcode
```bash
open KiaMaps.xcodeproj
```

#### 3. Apply Configuration File
- Select `KiaMaps` project in navigator
- Select the project (not a target) at the top
- In the Info tab, under Configurations:
  - Click the arrow next to Debug
  - For each target, set Configuration File to `Config/Signing.xcconfig`
  - Repeat for Release configuration

#### 4. Verify Signing Settings
- Go to each target's `Signing & Capabilities` tab
- Verify that the settings from the xcconfig file are applied:
  - Team should match your `DEVELOPMENT_TEAM`
  - Bundle Identifier should be set correctly
  - Provisioning Profile should match your settings
- The values should appear in gray (inherited from xcconfig)

#### 5. Build and Run
- Select your physical device (required for Intents)
- Choose `KiaMaps` scheme
- Build and run with Cmd+R

### Troubleshooting

**Profile mismatch**: Ensure provisioning profile includes your device UDID

**Bundle ID conflicts**: Verify bundle IDs match those in provisioning profile

**Entitlements**: Check that App Groups and Intents entitlements match profile

**Team selection**: Confirm correct team is selected for all targets

### Device Requirements
- Physical iOS device (required)
- iOS 14.0+ for full Intents functionality
- Device must be registered in provisioning profile