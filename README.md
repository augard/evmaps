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

## Vehicle Parameters

The app uses detailed vehicle parameters to provide accurate EV-specific navigation in Apple Maps. These parameters enable:
- **Energy consumption calculations** based on speed, elevation, and auxiliary power usage
- **Charging time estimations** using real charging curves
- **Route planning** with optimal charging stops

### Parameter Categories

#### 1. Charging Configuration
- **Supported Connectors**: Defines which charging standards the vehicle supports (e.g., Type 2 AC, CCS2 DC)
- **Maximum Power**: Peak charging rates for each connector type
- **Charging Curve**: Detailed power delivery at different battery levels

#### 2. Energy Consumption Model
- **10 consumption scenarios**: Array of values representing different driving efficiency conditions (validated against real test data)
- **Elevation impact**: Additional energy for climbing, recovery when descending
- **Auxiliary power**: Constant draw from electronics, climate control (~670W)

#### 3. Battery & Range
- **Maximum distance**: WLTP-rated range in kilometers
- **Battery capacity**: Usable energy storage (e.g., ~90 kWh for Taycan)
- **Efficiency factors**: Charging losses and energy conversion efficiency

### Example: Porsche Taycan Parameters

```swift
// Charging: Supports up to 234 kW DC fast charging
maximumPower(.ccs2) = 234.0 kW

// Consumption: 10 efficiency scenarios validated against real-world data
consumptionValues = [
    0.172,  // 172 Wh/km - Optimal efficiency (matches WLTP ~180 Wh/km)
    0.183,  // 183 Wh/km - Steady highway (~90 km/h)
    0.205,  // 205 Wh/km - Moderate highway speeds  
    0.258   // 258 Wh/km - High-speed Autobahn (validated at 130 km/h)
    // ... 6 more values covering city, mixed, and demanding conditions
] // Wh per meter

// Charging curve: Maintains high power to ~50% SOC
0-34 kWh: 232 kW peak power
34-50 kWh: Gradual taper to 144 kW
50-80 kWh: Further reduction for battery protection
80-100%: Trickle charge at 13 kW
```

#### Real-World Validation

The consumption parameters have been validated against actual Taycan test data:
- **WLTP efficiency**: ~180 Wh/km matches code value of 172.1 Wh/km
- **90 km/h highway**: ~190 Wh/km falls within code range (183-205 Wh/km)  
- **130 km/h Autobahn**: 220-260 Wh/km matches code value of 258.4 Wh/km
- **Range coverage**: 172-258 Wh/km spans from optimal to high-speed conditions

### Adding New Vehicle Support

To add support for a new vehicle model:

1. Create a new parameters file following the `VehicleParameters` protocol
2. Define all required consumption and charging parameters
3. Add the vehicle case to `VehicleManager.vehicleParameter`
4. Update API configuration if needed

See `KiaMaps/Core/Vehicle/` for implementation examples.