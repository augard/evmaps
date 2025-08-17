//
//  VehicleMapView.swift
//  KiaMaps
//
//  Created by Claude Code on 21.07.2025.
//  Tesla-inspired map integration with custom vehicle annotations and charging stations
//

import SwiftUI
import MapKit
import CoreLocation

/// Tesla-style map view with vehicle location and charging station integration
struct VehicleMapView: View {
    let vehicle: Vehicle?
    let vehicleStatus: VehicleStatus
    let vehicleLocation: Location
    let onChargingStationTap: ((ChargingStation) -> Void)?
    let onVehicleTap: (() -> Void)?
    
    @StateObject private var locationManager = LocationManager()
    @State private var region: MKCoordinateRegion
    @State private var currentMapStyle: CurrentMapStyle = .standard
    
    enum CurrentMapStyle: CaseIterable {
        case standard, hybrid, imagery
        
        var mapStyle: MapStyle {
            switch self {
            case .standard: return .standard
            case .hybrid: return .hybrid
            case .imagery: return .imagery
            }
        }
    }
    @State private var showingChargingStations = true
    @State private var selectedAnnotation: CustomMapAnnotation?
    
    // Mock charging stations for demo
    @State private var chargingStations: [ChargingStation] = []
    
    init(
        vehicle: Vehicle? = nil,
        vehicleStatus: VehicleStatus,
        vehicleLocation: Location,
        onChargingStationTap: ((ChargingStation) -> Void)? = nil,
        onVehicleTap: (() -> Void)? = nil
    ) {
        self.vehicle = vehicle
        self.vehicleStatus = vehicleStatus
        self.vehicleLocation = vehicleLocation
        self.onChargingStationTap = onChargingStationTap
        self.onVehicleTap = onVehicleTap
        
        // Initialize region around vehicle location
        let vehicleCoordinate = CLLocationCoordinate2D(
            latitude: vehicleLocation.geoCoordinate.latitude,
            longitude: vehicleLocation.geoCoordinate.longitude
        )
        
        self._region = State(initialValue: MKCoordinateRegion(
            center: vehicleCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        ))
    }
    
    var body: some View {
        ZStack {
            // Main Map with annotations using the older but working API
            Map(coordinateRegion: $region, 
                interactionModes: .all, 
                showsUserLocation: false, 
                userTrackingMode: .constant(.none),
                annotationItems: mapAnnotations) { annotation in
                MapAnnotation(coordinate: annotation.coordinate) {
                    Group {
                        switch annotation.type {
                        case .vehicle:
                            VehicleAnnotationView(
                                batteryLevel: Double(vehicleStatus.green.batteryManagement.batteryRemain.ratio) / 100.0,
                                isCharging: isVehicleCharging,
                                heading: vehicleLocation.heading
                            )
                            .scaleEffect(selectedAnnotation?.id == annotation.id ? 1.3 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedAnnotation?.id)
                            .onTapGesture {
                                selectedAnnotation = annotation
                                onVehicleTap?()
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        case .chargingStation(let station):
                            ChargingStationAnnotationView(
                                station: station,
                                isSelected: selectedAnnotation?.id == annotation.id
                            )
                            .onTapGesture {
                                selectedAnnotation = annotation
                                onChargingStationTap?(station)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                    }
                }
            }
            .mapStyle(currentMapStyle.mapStyle)
            .onAppear {
                loadNearbyChargingStations()
            }
            
            // Map Controls Overlay
            mapControlsOverlay
            
            // Selected Annotation Details
            if let annotation = selectedAnnotation {
                annotationDetailCard(for: annotation)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.large))
    }
    
    // MARK: - Map Controls Overlay
    
    private var mapControlsOverlay: some View {
        VStack {
            HStack {
                Spacer()
                
                VStack(spacing: KiaDesign.Spacing.small) {
                    // Map Style Toggle
                    KiaButton(
                        "",
                        icon: "map.fill",
                        style: .secondary,
                        size: .small,
                        action: toggleMapStyle
                    )
                    
                    // Charging Stations Toggle
                    KiaButton(
                        "",
                        icon: "bolt.car.fill",
                        style: showingChargingStations ? .primary : .secondary,
                        size: .small,
                        action: toggleChargingStations
                    )
                    
                    // Center on Vehicle
                    KiaButton(
                        "",
                        icon: "location.fill",
                        style: .primary,
                        size: .small,
                        action: centerOnVehicle
                    )
                }
                .padding(KiaDesign.Spacing.medium)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Annotation Detail Card
    
    @ViewBuilder
    private func annotationDetailCard(for annotation: CustomMapAnnotation) -> some View {
        VStack {
            Spacer()
            
            KiaCard(elevation: .floating) {
                switch annotation.type {
                case .vehicle:
                    vehicleDetailContent
                case .chargingStation(let station):
                    chargingStationDetailContent(station)
                }
            }
            .padding(KiaDesign.Spacing.medium)
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            ))
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    selectedAnnotation = nil
                }
            }
        }
    }
    
    private var vehicleDetailContent: some View {
        VStack(spacing: KiaDesign.Spacing.medium) {
            HStack {
                Image(systemName: "car.fill")
                    .font(.title2)
                    .foregroundStyle(KiaDesign.Colors.primary)
                
                VStack(alignment: .leading, spacing: 2) {
                    // Use real vehicle nickname from API
                    Text(vehicleNickname)
                        .font(KiaDesign.Typography.bodyBold)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    Text("Current Location")
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                }
                
                Spacer()
                
                Button("Dismiss") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedAnnotation = nil
                    }
                }
                .font(KiaDesign.Typography.caption)
                .foregroundStyle(KiaDesign.Colors.accent)
            }
            
            // Vehicle info grid with dividers
            VStack(spacing: KiaDesign.Spacing.medium) {
                // First row: Battery and Range
                HStack(spacing: KiaDesign.Spacing.large) {
                    VStack(spacing: 4) {
                        Text("\(Int(Double(vehicleStatus.green.batteryManagement.batteryRemain.ratio)))%")
                            .font(KiaDesign.Typography.body)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                        
                        Text("Battery")
                            .font(KiaDesign.Typography.caption)
                            .foregroundStyle(KiaDesign.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider()
                        .frame(height: 30)
                    
                    VStack(spacing: 4) {
                        let dte = vehicleStatus.drivetrain.fuelSystem.dte
                        let rangeUnit = dte.unit == .kilometers ? "km" : "mi"
                        Text("\(dte.total) \(rangeUnit)")
                            .font(KiaDesign.Typography.body)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                        
                        Text("Range")
                            .font(KiaDesign.Typography.caption)
                            .foregroundStyle(KiaDesign.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Second row: Speed and Altitude
                HStack(spacing: KiaDesign.Spacing.large) {
                    VStack(spacing: 4) {
                        let speed = vehicleLocation.speed
                        let speedUnit = speed.unit == .km ? "km/h" : speed.unit == .miles ? "mph" : "m/s"
                        let speedText = speed.value > 0 ? "\(Int(speed.value)) \(speedUnit)" : (isVehicleCharging ? "Charging" : "Parked")
                        
                        Text(speedText)
                            .font(KiaDesign.Typography.body)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                        
                        Text(speed.value > 0 ? "Speed" : "Status")
                            .font(KiaDesign.Typography.caption)
                            .foregroundStyle(KiaDesign.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider()
                        .frame(height: 30)
                    
                    VStack(spacing: 4) {
                        let altitude = vehicleLocation.geoCoordinate.altitude
                        Text("\(Int(altitude)) m")
                            .font(KiaDesign.Typography.body)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                        
                        Text("Altitude")
                            .font(KiaDesign.Typography.caption)
                            .foregroundStyle(KiaDesign.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    private func chargingStationDetailContent(_ station: ChargingStation) -> some View {
        VStack(spacing: KiaDesign.Spacing.medium) {
            HStack {
                Image(systemName: "bolt.car.fill")
                    .font(.title2)
                    .foregroundStyle(station.powerLevel.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.name)
                        .font(KiaDesign.Typography.bodyBold)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    Text("\(String(format: "%.1f", station.distanceKm)) km away")
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                }
                
                Spacer()
                
                Button("Dismiss") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedAnnotation = nil
                    }
                }
                .font(KiaDesign.Typography.caption)
                .foregroundStyle(KiaDesign.Colors.accent)
            }
            
            // Charging station info grid with dividers
            VStack(spacing: KiaDesign.Spacing.medium) {
                // First row: Max Power and Available Ports
                HStack(spacing: KiaDesign.Spacing.large) {
                    VStack(spacing: 4) {
                        Text("\(station.powerLevel.maxPower) kW")
                            .font(KiaDesign.Typography.body)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                        
                        Text("Max Power")
                            .font(KiaDesign.Typography.caption)
                            .foregroundStyle(KiaDesign.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider()
                        .frame(height: 30)
                    
                    VStack(spacing: 4) {
                        Text("\(station.availablePorts)/\(station.totalPorts)")
                            .font(KiaDesign.Typography.body)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                        
                        Text("Available")
                            .font(KiaDesign.Typography.caption)
                            .foregroundStyle(KiaDesign.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Second row: Price and Distance
                HStack(spacing: KiaDesign.Spacing.large) {
                    VStack(spacing: 4) {
                        Text(station.pricePerKwh, format: .currency(code: "USD"))
                            .font(KiaDesign.Typography.body)
                            .fontWeight(.semibold)
                        
                        Text("per kWh")
                            .font(KiaDesign.Typography.caption)
                            .foregroundStyle(KiaDesign.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider()
                        .frame(height: 30)
                    
                    VStack(spacing: 4) {
                        Text("\(String(format: "%.1f", station.distanceKm)) km")
                            .font(KiaDesign.Typography.body)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                        
                        Text("Distance")
                            .font(KiaDesign.Typography.caption)
                            .foregroundStyle(KiaDesign.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var isVehicleCharging: Bool {
        vehicleStatus.isCharging
    }
    
    private var vehicleNickname: String {
        vehicle?.nickname ?? "My Vehicle"
    }
    
    private var vehicleCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: vehicleLocation.geoCoordinate.latitude,
            longitude: vehicleLocation.geoCoordinate.longitude
        )
    }
    
    private var mapAnnotations: [CustomMapAnnotation] {
        var annotations: [CustomMapAnnotation] = []
        
        // Add vehicle annotation
        annotations.append(CustomMapAnnotation(
            id: "vehicle",
            coordinate: vehicleCoordinate,
            type: .vehicle
        ))
        
        // Add charging station annotations if enabled
        if showingChargingStations {
            for station in chargingStations {
                annotations.append(CustomMapAnnotation(
                    id: station.id,
                    coordinate: station.coordinate,
                    type: .chargingStation(station)
                ))
            }
        }
        
        return annotations
    }
    
    
    // MARK: - Actions
    
    private func toggleMapStyle() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch currentMapStyle {
            case .standard:
                currentMapStyle = .hybrid
            case .hybrid:
                currentMapStyle = .imagery
            case .imagery:
                currentMapStyle = .standard
            }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func toggleChargingStations() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showingChargingStations.toggle()
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }
    
    private func centerOnVehicle() {
        let vehicleCoordinate = CLLocationCoordinate2D(
            latitude: vehicleLocation.geoCoordinate.latitude,
            longitude: vehicleLocation.geoCoordinate.longitude
        )
        
        withAnimation(.easeInOut(duration: 1.0)) {
            region.center = vehicleCoordinate
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func loadNearbyChargingStations() {
        // Mock charging stations around vehicle location
        let vehicleLocation = CLLocationCoordinate2D(
            latitude: vehicleLocation.geoCoordinate.latitude,
            longitude: vehicleLocation.geoCoordinate.longitude
        )
        
        chargingStations = [
            ChargingStation(
                id: "station1",
                name: "Tesla Supercharger",
                coordinate: CLLocationCoordinate2D(
                    latitude: vehicleLocation.latitude + 0.005,
                    longitude: vehicleLocation.longitude + 0.008
                ),
                powerLevel: .superfast,
                totalPorts: 8,
                availablePorts: 3,
                pricePerKwh: 0.45,
                distanceKm: 1.2
            ),
            ChargingStation(
                id: "station2",
                name: "ChargePoint DC",
                coordinate: CLLocationCoordinate2D(
                    latitude: vehicleLocation.latitude - 0.003,
                    longitude: vehicleLocation.longitude + 0.012
                ),
                powerLevel: .fast,
                totalPorts: 4,
                availablePorts: 2,
                pricePerKwh: 0.38,
                distanceKm: 2.1
            ),
            ChargingStation(
                id: "station3",
                name: "EVgo Fast Charging",
                coordinate: CLLocationCoordinate2D(
                    latitude: vehicleLocation.latitude + 0.008,
                    longitude: vehicleLocation.longitude - 0.006
                ),
                powerLevel: .rapid,
                totalPorts: 6,
                availablePorts: 1,
                pricePerKwh: 0.42,
                distanceKm: 1.8
            )
        ]
    }
}

// MARK: - Map Annotation Models

struct CustomMapAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let type: AnnotationType
    
    enum AnnotationType {
        case vehicle
        case chargingStation(ChargingStation)
    }
}

struct ChargingStation: Identifiable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let powerLevel: PowerLevel
    let totalPorts: Int
    let availablePorts: Int
    let pricePerKwh: Double
    let distanceKm: Double
    
    enum PowerLevel {
        case slow      // AC charging (7-22 kW)
        case fast      // DC fast charging (50-75 kW)
        case rapid     // Rapid charging (100-150 kW)
        case superfast // Ultra-rapid charging (150+ kW)
        
        var maxPower: Int {
            switch self {
            case .slow: return 22
            case .fast: return 75
            case .rapid: return 150
            case .superfast: return 250
            }
        }
        
        var color: Color {
            switch self {
            case .slow: return KiaDesign.Colors.textSecondary
            case .fast: return KiaDesign.Colors.accent
            case .rapid: return KiaDesign.Colors.primary
            case .superfast: return KiaDesign.Colors.charging
            }
        }
        
        var displayName: String {
            switch self {
            case .slow: return "AC"
            case .fast: return "Fast"
            case .rapid: return "Rapid"
            case .superfast: return "Ultra"
            }
        }
    }
}

// MARK: - Vehicle Annotation View

struct VehicleAnnotationView: View {
    let batteryLevel: Double
    let isCharging: Bool
    let heading: Double
    
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            // Outer glow for charging
            if isCharging {
                Circle()
                    .fill(KiaDesign.Colors.charging.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .opacity(pulseAnimation ? 0.3 : 0.6)
                    .blur(radius: 2)
            }
            
            // Main vehicle marker
            Circle()
                .fill(vehicleColor)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                )
                .shadow(
                    color: .black.opacity(0.2),
                    radius: 4,
                    y: 2
                )
            
            // Vehicle icon
            Image(systemName: "car.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(heading - 180))
                .padding(.bottom, 2)
        }
        .onAppear {
            if isCharging {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            }
        }
    }
    
    private var vehicleColor: Color {
        if isCharging {
            return KiaDesign.Colors.charging
        } else if batteryLevel < 0.2 {
            return KiaDesign.Colors.warning
        } else {
            return KiaDesign.Colors.primary
        }
    }
}

// MARK: - Charging Station Annotation View

struct ChargingStationAnnotationView: View {
    let station: ChargingStation
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            // Selection indicator
            if isSelected {
                Circle()
                    .fill(station.powerLevel.color.opacity(0.3))
                    .frame(width: 50, height: 50)
            }
            
            // Main marker
            RoundedRectangle(cornerRadius: 8)
                .fill(station.powerLevel.color)
                .frame(width: 32, height: 32)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(
                    color: .black.opacity(0.2),
                    radius: 3,
                    y: 2
                )
            
            // Charging icon
            Image(systemName: "bolt.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
            
            // Availability indicator
            if station.availablePorts == 0 {
                Circle()
                    .fill(KiaDesign.Colors.error)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 1)
                    )
                    .offset(x: 12, y: -12)
            }
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
}

// MARK: - Preview

#Preview("Vehicle Map - Standard") {
    VehicleMapView(
        vehicle: MockVehicleData.mockVehicle,
        vehicleStatus: MockVehicleData.standard,
        vehicleLocation: MockVehicleData.standard.location!,
        onChargingStationTap: { station in
            print("Tapped charging station: \(station.name)")
        },
        onVehicleTap: {
            print("Tapped vehicle")
        }
    )
    .frame(height: 400)
    .padding()
    .background(KiaDesign.Colors.background)
}

#Preview("Vehicle Map - Charging") {
    VehicleMapView(
        vehicle: MockVehicleData.mockVehicle,
        vehicleStatus: MockVehicleData.charging,
        vehicleLocation: MockVehicleData.standard.location!,
        onChargingStationTap: { station in
            print("Tapped charging station: \(station.name)")
        },
        onVehicleTap: {
            print("Tapped vehicle")
        }
    )
    .frame(height: 400)
    .padding()
    .background(KiaDesign.Colors.background)
}
