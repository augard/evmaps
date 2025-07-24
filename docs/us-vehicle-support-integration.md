# US Vehicle Support Integration Guide

This document outlines the findings from researching the Hyundai-Kia Connect API implementation and provides recommendations for adding US vehicle support to the KiaMaps application.

## Overview

Based on analysis of the [hyundai_kia_connect_api](https://github.com/Hyundai-Kia-Connect/hyundai_kia_connect_api) Python implementation, US vehicle APIs differ significantly from European endpoints currently supported in the app. This guide provides a roadmap for implementing US support.

## Key Differences: US vs EU APIs

### API Architecture
- **Regional Separation**: US and Canada share identical APIs but differ completely from European endpoints
- **Base URLs**:
  - **EU (Current)**: `https://prd.eu-ccapi.{brand}.com`
  - **US Kia**: `https://myuvo.kiausa.com`
  - **US Hyundai**: `https://api.telematics.hyundaiusa.com`
  - **US Genesis**: TBD (likely `https://api.telematics.genesis.com`)

### Authentication Flow Comparison

| Aspect | EU (Current Implementation) | US (From Python API) |
|--------|---------------------------|---------------------|
| Login Flow | Multi-step OAuth2 with device registration | Simpler PIN-based authentication |
| Endpoints | `/api/v1/user/signin` | `/v2/ac/` structure |
| Headers | Standard OAuth headers | Specific headers: `from: SPA`, `to: ISS` |
| Token Management | Complex token exchange | Direct token response |
| Device Registration | Required with push notifications | Optional/Different approach |

## Implementation Recommendations

### 1. Extend Configuration Architecture

#### Add US Region Support
Update `ApiConfiguration.swift` to handle US region:

```swift
enum ApiRegion {
    case europe
    case usa      // Add this
    case canada   // Add this
    case china
    case korea
}
```

#### Create US Configuration
Add new file `ApiConfigurationUSA.swift`:

```swift
enum ApiConfigurationUSA: String, ApiConfiguration {
    case kia
    case hyundai
    case genesis
    
    var key: String {
        switch self {
        case .kia: "kia"
        case .hyundai: "hyundai"
        case .genesis: "genesis"
        }
    }
    
    var baseUrl: String {
        switch self {
        case .kia: "https://myuvo.kiausa.com"
        case .hyundai: "https://api.telematics.hyundaiusa.com"
        case .genesis: "https://api.telematics.genesis.com" // Verify this
        }
    }
    
    var loginUrl: String {
        switch self {
        case .kia: "https://myuvo.kiausa.com"
        case .hyundai: "https://www.hyundaiusa.com"
        case .genesis: "https://www.genesis.com"
        }
    }
    
    var port: Int { 443 }
    
    var serviceAgent: String { "okhttp/3.12.0" }
    
    var userAgent: String {
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15"
    }
    
    var acceptHeader: String {
        "application/json"
    }
    
    // US-specific IDs will need to be determined
    var serviceId: String { "" }  // TODO: Extract from US app
    var appId: String { "" }       // TODO: Extract from US app
    var senderId: Int { 0 }        // TODO: Extract from US app
    var authClientId: String { "" } // TODO: Extract from US app
    var cfb: String { "" }         // TODO: Extract from US app
    var pushType: String { "GCM" }
}
```

### 2. Update Factory Pattern

Modify `ApiBrand.configuration(for:)` in `ApiConfiguration.swift`:

```swift
func configuration(for region: ApiRegion) -> ApiConfiguration {
    switch self {
    case .kia, .hyundai, .genesis:
        switch region {
        case .europe:
            guard let configuration = ApiConfigurationEurope(rawValue: rawValue) else {
                fatalError("Api region not supported")
            }
            return configuration
        case .usa, .canada:  // US and Canada share same API
            guard let configuration = ApiConfigurationUSA(rawValue: rawValue) else {
                fatalError("Api region not supported")
            }
            return configuration
        case .china, .korea:
            fatalError("Api region not supported")
        }
    }
}
```

### 3. Create US-Specific API Implementation

Create `ApiUSA.swift` extending the base `Api` class:

```swift
class ApiUSA: Api {
    override func login(username: String, password: String) async throws -> AuthorizationData {
        // US-specific login flow
        // Reference Python implementation for exact flow
        
        // Key differences:
        // 1. Different endpoint structure (/v2/ac/)
        // 2. PIN-based authentication
        // 3. Different header requirements
        // 4. Simpler token exchange
        
        // Implementation details from Python API research
    }
    
    // Override other methods as needed for US-specific endpoints
}
```

### 4. Update Endpoint Definitions

Add US-specific endpoints to `ApiEndpoints.swift`:

```swift
extension ApiEndpoint {
    // US-specific endpoints
    static func usaLogin() -> ApiEndpoint {
        ApiEndpoint("v2/ac/login")
    }
    
    static func usaVehicles() -> ApiEndpoint {
        ApiEndpoint("v2/ac/vehicles")
    }
    
    static func usaVehicleStatus(_ vehicleId: UUID) -> ApiEndpoint {
        ApiEndpoint("v2/ac/vehicles/\(vehicleId)/status")
    }
    
    // Add other US-specific endpoints based on Python implementation
}
```

### 5. Handle Response Differences

Create US-specific response models if needed:

```swift
// If US responses differ from EU
struct VehicleResponseUSA: Codable {
    // US-specific fields
}

struct VehicleStatusResponseUSA: Codable {
    // US-specific status fields
}
```

## Integration Steps

### Phase 1: Foundation
1. Add US region enum cases
2. Create `ApiConfigurationUSA` with placeholder values
3. Update factory pattern to handle US region
4. Add basic US endpoint definitions

### Phase 2: Authentication
1. Research exact US authentication flow from Python implementation
2. Implement US-specific login method
3. Handle US token management
4. Test with US credentials

### Phase 3: Vehicle Operations
1. Map US vehicle endpoints
2. Implement vehicle status retrieval
3. Add US-specific vehicle commands
4. Handle response format differences

### Phase 4: Testing & Refinement
1. Create mock US responses for testing
2. Test region switching
3. Verify data model compatibility
4. Handle edge cases

## Reference Implementation Patterns

### From Python API (VehicleManager)
```python
# Region handling
REGIONS = {
    1: REGION_EUROPE,
    2: REGION_CANADA, 
    3: REGION_USA,
    4: REGION_CHINA,
    5: REGION_AUSTRALIA
}

# Unified interface
vm = VehicleManager(region=3, brand=1, username="user", password="pass", pin="1234")
vm.check_and_refresh_token()
vm.update_all_vehicles_with_cached_state()
```

### Suggested Swift Pattern
```swift
// Region-aware API factory
let api = ApiFactory.create(brand: .kia, region: .usa)
let auth = try await api.login(username: "user", password: "pass", pin: "1234")
let vehicles = try await api.vehicles()
```

## Data Considerations

### Vehicle Features
- US vehicles may have different feature sets
- Climate control options may vary
- Charging parameters might differ for EVs

### Status Reporting
- Battery level reporting format
- Location data precision
- Unit preferences (miles vs kilometers)

## Testing Strategy

### 1. Mock Testing
- Create US response mocks based on Python API
- Test authentication flow with mocked endpoints
- Verify data parsing

### 2. Integration Testing
- Test with real US credentials (when available)
- Verify all vehicle operations
- Check error handling

### 3. Region Switching
- Test switching between EU and US accounts
- Verify proper cleanup between regions
- Handle mixed-region scenarios

## Security Considerations

1. **API Keys**: US API keys/secrets need to be extracted from official apps
2. **Certificate Pinning**: US endpoints may have different certificates
3. **Rate Limiting**: US APIs may have different rate limits
4. **Token Storage**: Ensure US tokens are stored separately from EU

## Next Steps

1. **Analyze Python Source**: Deep dive into `KiaUvoApiUSA.py` and `HyundaiBlueLinkApiUSA.py`
2. **Extract API Secrets**: Use MITM proxy to capture US app traffic for API keys
3. **Prototype**: Start with basic US configuration and login flow
4. **Iterate**: Add vehicle operations incrementally
5. **Test**: Comprehensive testing with US vehicles

## Resources

- [hyundai_kia_connect_api](https://github.com/Hyundai-Kia-Connect/hyundai_kia_connect_api) - Python implementation
- [bluelinky](https://github.com/Hacksore/bluelinky) - Node.js implementation
- [kia_uvo](https://github.com/Hyundai-Kia-Connect/kia_uvo) - Home Assistant integration
- [Reverse Engineering Blog](https://blog.kumo.dev/2024/05/22/reverse_engineering_hkg_apps.html) - Technical details

## Conclusion

Adding US vehicle support is achievable with the current architecture. The main challenges are:
1. Obtaining US-specific API keys and secrets
2. Implementing the different authentication flow
3. Handling response format differences
4. Testing with actual US vehicles

The existing code structure with its protocol-based design and factory pattern makes it well-suited for multi-region support. Following the patterns from the Python implementation will provide a solid foundation for US integration.