//
//  SwipeNavigationView.swift
//  KiaMaps
//
//  Created by Claude Code on 21.07.2025.
//  Tesla-inspired swipe navigation with smooth transitions and haptic feedback
//

import SwiftUI

/// Tesla-style swipe navigation container with smooth page transitions
struct SwipeNavigationView<Content: View>: View {
    let pages: [NavigationPage]
    let content: (NavigationPage, Bool) -> Content
    
    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    
    private let pageWidth: CGFloat = UIScreen.main.bounds.width
    private let dragThreshold: CGFloat = 50
    
    init(
        pages: [NavigationPage],
        @ViewBuilder content: @escaping (NavigationPage, Bool) -> Content
    ) {
        self.pages = pages
        self.content = content
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Page indicator
            pageIndicator
                .padding(.top, KiaDesign.Spacing.medium)
            
            // Page content with swipe gesture
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        content(page, index == currentIndex)
                            .frame(width: geometry.size.width)
                            .clipped()
                    }
                }
                .offset(x: -CGFloat(currentIndex) * geometry.size.width + dragOffset)
                .animation(
                    isDragging ? .none : .spring(response: 0.5, dampingFraction: 0.8),
                    value: currentIndex
                )
                .animation(
                    isDragging ? .none : .spring(response: 0.3, dampingFraction: 0.9),
                    value: dragOffset
                )
                .gesture(
                    DragGesture()
                        .onChanged(handleDragChanged)
                        .onEnded(handleDragEnded)
                )
            }
            .clipped()
        }
    }
    
    // MARK: - Page Indicator
    
    private var pageIndicator: some View {
        HStack(spacing: KiaDesign.Spacing.small) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                pageIndicatorDot(for: index, page: page)
            }
        }
        .padding(.horizontal, KiaDesign.Spacing.large)
    }
    
    private func pageIndicatorDot(for index: Int, page: NavigationPage) -> VStack<TupleView<(some View, some View)>> {
        VStack(spacing: 4) {
            // Icon indicator
            Image(systemName: page.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(index == currentIndex ? KiaDesign.Colors.primary : KiaDesign.Colors.textTertiary)
                .scaleEffect(index == currentIndex ? 1.2 : 1.0)
            
            // Progress bar
            Rectangle()
                .fill(index == currentIndex ? KiaDesign.Colors.primary : KiaDesign.Colors.textTertiary.opacity(0.3))
                .frame(width: index == currentIndex ? 40 : 20, height: 3)
                .clipShape(Capsule())
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentIndex)
        .onTapGesture {
            withHapticFeedback(.selection) {
                currentIndex = index
            }
        }
    }
    
    // MARK: - Gesture Handling
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        if !isDragging {
            isDragging = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        dragOffset = value.translation.x
        
        // Provide haptic feedback when crossing threshold
        let threshold = pageWidth * 0.3
        if abs(dragOffset) > threshold && abs(value.predictedEndTranslation.x) > threshold * 1.5 {
            let direction = dragOffset > 0 ? -1 : 1
            let targetIndex = currentIndex + direction
            
            if targetIndex >= 0 && targetIndex < pages.count {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        isDragging = false
        
        let dragDistance = value.translation.x
        let dragVelocity = value.predictedEndTranslation.x
        
        // Determine if swipe should trigger page change
        let shouldChangePage = abs(dragDistance) > dragThreshold || abs(dragVelocity) > pageWidth * 0.5
        
        if shouldChangePage {
            let direction = dragDistance > 0 ? -1 : 1
            let targetIndex = currentIndex + direction
            
            if targetIndex >= 0 && targetIndex < pages.count {
                withHapticFeedback(.impact(.medium)) {
                    currentIndex = targetIndex
                }
            } else {
                // Bounce back with haptic feedback
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
        
        // Reset drag offset
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            dragOffset = 0
        }
    }
    
    // MARK: - Public Methods
    
    /// Navigate to specific page programmatically
    func navigateTo(pageIndex: Int) {
        guard pageIndex >= 0 && pageIndex < pages.count else { return }
        
        withHapticFeedback(.selection) {
            currentIndex = pageIndex
        }
    }
    
    /// Navigate to specific page by ID
    func navigateTo(pageId: String) {
        if let index = pages.firstIndex(where: { $0.id == pageId }) {
            navigateTo(pageIndex: index)
        }
    }
}

// MARK: - Navigation Page Model

struct NavigationPage: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String
    let accessibilityLabel: String?
    
    init(id: String, title: String, icon: String, accessibilityLabel: String? = nil) {
        self.id = id
        self.title = title
        self.icon = icon
        self.accessibilityLabel = accessibilityLabel ?? title
    }
    
    static func == (lhs: NavigationPage, rhs: NavigationPage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Haptic Feedback Helper

private extension View {
    func withHapticFeedback<T>(_ feedback: HapticFeedback, action: () -> T) -> T {
        let result = action()
        
        switch feedback {
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .impact(let style):
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        case .notification(let type):
            UINotificationFeedbackGenerator().notificationOccurred(type)
        }
        
        return result
    }
}

private enum HapticFeedback {
    case selection
    case impact(UIImpactFeedbackGenerator.FeedbackStyle)
    case notification(UINotificationFeedbackGenerator.FeedbackType)
}

// MARK: - Pull-to-Refresh Container

/// Tesla-style pull-to-refresh with custom animations
struct PullToRefreshView<Content: View>: View {
    let content: Content
    let onRefresh: () async -> Void
    
    @State private var refreshOffset: CGFloat = 0
    @State private var isRefreshing: Bool = false
    @State private var refreshProgress: Double = 0
    
    private let refreshThreshold: CGFloat = 80
    
    init(@ViewBuilder content: () -> Content, onRefresh: @escaping () async -> Void) {
        self.content = content()
        self.onRefresh = onRefresh
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Pull-to-refresh indicator
                pullToRefreshIndicator
                    .frame(height: max(0, refreshOffset))
                    .clipped()
                
                content
            }
        }
        .coordinateSpace(name: "pullToRefresh")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            handleScrollOffset(value)
        }
        .refreshable {
            await performRefresh()
        }
    }
    
    private var pullToRefreshIndicator: some View {
        VStack {
            Spacer()
            
            if isRefreshing {
                // Refreshing animation
                refreshingAnimation
            } else {
                // Pull indicator
                pullIndicator
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(KiaDesign.Colors.background.opacity(0.9))
    }
    
    private var refreshingAnimation: some View {
        VStack(spacing: KiaDesign.Spacing.medium) {
            // Animated charging icon
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(KiaDesign.Colors.charging)
                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                .animation(
                    .linear(duration: 1.0).repeatForever(autoreverses: false),
                    value: isRefreshing
                )
            
            Text("Updating vehicle status...")
                .font(KiaDesign.Typography.caption)
                .foregroundStyle(KiaDesign.Colors.textSecondary)
        }
    }
    
    private var pullIndicator: some View {
        VStack(spacing: KiaDesign.Spacing.small) {
            // Progress circle
            ZStack {
                Circle()
                    .stroke(KiaDesign.Colors.textTertiary.opacity(0.3), lineWidth: 3)
                    .frame(width: 40, height: 40)
                
                Circle()
                    .trim(from: 0, to: refreshProgress)
                    .stroke(
                        KiaDesign.Colors.primary,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                
                // Arrow or checkmark
                Image(systemName: refreshProgress >= 1.0 ? "checkmark" : "arrow.down")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(refreshProgress >= 1.0 ? KiaDesign.Colors.success : KiaDesign.Colors.textSecondary)
                    .scaleEffect(refreshProgress >= 1.0 ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: refreshProgress >= 1.0)
            }
            
            Text(refreshProgress >= 1.0 ? "Release to refresh" : "Pull to refresh")
                .font(KiaDesign.Typography.caption)
                .foregroundStyle(KiaDesign.Colors.textSecondary)
        }
        .scaleEffect(min(1.0, refreshProgress + 0.3))
        .opacity(min(1.0, refreshProgress + 0.2))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: refreshProgress)
    }
    
    private func handleScrollOffset(_ offset: CGFloat) {
        guard !isRefreshing else { return }
        
        if offset > 0 {
            refreshOffset = offset
            refreshProgress = min(1.0, offset / refreshThreshold)
            
            // Haptic feedback when reaching threshold
            if refreshProgress >= 1.0 && refreshOffset < refreshThreshold {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } else {
            refreshOffset = 0
            refreshProgress = 0
        }
    }
    
    private func performRefresh() async {
        guard !isRefreshing else { return }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isRefreshing = true
        }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        await onRefresh()
        
        // Delay to show completion state
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isRefreshing = false
            refreshOffset = 0
            refreshProgress = 0
        }
    }
}

// MARK: - Scroll Offset Preference

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

private struct ScrollOffsetModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geometry.frame(in: .named("pullToRefresh")).minY
                        )
                }
            )
    }
}

// MARK: - Loading State Components

/// Tesla-inspired loading states with smooth animations
struct LoadingStateView: View {
    let state: LoadingState
    let retryAction: (() -> Void)?
    
    var body: some View {
        VStack(spacing: KiaDesign.Spacing.xl) {
            // Main loading animation
            loadingAnimation
            
            // Status text
            VStack(spacing: KiaDesign.Spacing.small) {
                Text(state.title)
                    .font(KiaDesign.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                if let subtitle = state.subtitle {
                    Text(subtitle)
                        .font(KiaDesign.Typography.body)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Retry button for error states
            if case .error = state, let retryAction = retryAction {
                KiaButton(
                    "Try Again",
                    icon: "arrow.clockwise",
                    style: .secondary,
                    size: .medium,
                    hapticFeedback: .medium,
                    action: retryAction
                )
            }
        }
        .padding(KiaDesign.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KiaDesign.Colors.background)
    }
    
    @ViewBuilder
    private var loadingAnimation: some View {
        switch state {
        case .loading:
            loadingSpinner
        case .success:
            successAnimation
        case .error:
            errorAnimation
        case .empty:
            emptyStateAnimation
        }
    }
    
    private var loadingSpinner: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(KiaDesign.Colors.textTertiary.opacity(0.2), lineWidth: 4)
                .frame(width: 80, height: 80)
            
            // Animated progress ring
            Circle()
                .trim(from: 0.0, to: 0.7)
                .stroke(
                    KiaDesign.Colors.primary,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(-90))
                .animation(
                    .linear(duration: 1.0).repeatForever(autoreverses: false),
                    value: UUID()
                )
            
            // Center icon
            Image(systemName: "car.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(KiaDesign.Colors.primary)
        }
    }
    
    private var successAnimation: some View {
        ZStack {
            // Success circle
            Circle()
                .fill(KiaDesign.Colors.success.opacity(0.1))
                .frame(width: 80, height: 80)
            
            Circle()
                .stroke(KiaDesign.Colors.success, lineWidth: 4)
                .frame(width: 80, height: 80)
                .scaleEffect(1.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: UUID())
            
            // Checkmark
            Image(systemName: "checkmark")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(KiaDesign.Colors.success)
                .scaleEffect(1.2)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: UUID())
        }
    }
    
    private var errorAnimation: some View {
        ZStack {
            // Error circle
            Circle()
                .fill(KiaDesign.Colors.error.opacity(0.1))
                .frame(width: 80, height: 80)
            
            Circle()
                .stroke(KiaDesign.Colors.error, lineWidth: 4)
                .frame(width: 80, height: 80)
            
            // Error icon
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(KiaDesign.Colors.error)
        }
    }
    
    private var emptyStateAnimation: some View {
        ZStack {
            // Empty circle
            Circle()
                .stroke(KiaDesign.Colors.textTertiary.opacity(0.3), lineWidth: 2, dash: [8, 4])
                .frame(width: 80, height: 80)
            
            // Empty icon
            Image(systemName: "tray")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(KiaDesign.Colors.textTertiary)
        }
    }
}

// MARK: - Loading State Model

enum LoadingState {
    case loading
    case success
    case error(String)
    case empty(String)
    
    var title: String {
        switch self {
        case .loading:
            return "Loading..."
        case .success:
            return "Success!"
        case .error:
            return "Something went wrong"
        case .empty:
            return "No data available"
        }
    }
    
    var subtitle: String? {
        switch self {
        case .loading:
            return "Fetching latest vehicle data"
        case .success:
            return "Vehicle status updated"
        case .error(let message):
            return message
        case .empty(let message):
            return message
        }
    }
}

// MARK: - Preview

#Preview("Swipe Navigation") {
    let pages = [
        NavigationPage(id: "overview", title: "Overview", icon: "car.fill"),
        NavigationPage(id: "battery", title: "Battery", icon: "battery.75"),
        NavigationPage(id: "climate", title: "Climate", icon: "thermometer"),
        NavigationPage(id: "map", title: "Map", icon: "map.fill")
    ]
    
    SwipeNavigationView(pages: pages) { page, isActive in
        VStack {
            Text(page.title)
                .font(.title)
                .fontWeight(.bold)
            
            Text("This is the \(page.title) page")
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isActive ? KiaDesign.Colors.cardBackground : KiaDesign.Colors.background)
        .padding()
    }
    .background(KiaDesign.Colors.background)
}

#Preview("Pull to Refresh") {
    PullToRefreshView(
        content: {
            LazyVStack {
                ForEach(0..<20) { index in
                    Text("Item \(index)")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(KiaDesign.Colors.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        },
        onRefresh: {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }
    )
    .background(KiaDesign.Colors.background)
}

#Preview("Loading States") {
    ScrollView {
        LazyVStack(spacing: 40) {
            LoadingStateView(state: .loading, retryAction: nil)
                .frame(height: 300)
            
            LoadingStateView(state: .success, retryAction: nil)
                .frame(height: 300)
            
            LoadingStateView(
                state: .error("Failed to connect to vehicle. Please check your internet connection and try again."),
                retryAction: { print("Retry") }
            )
            .frame(height: 300)
            
            LoadingStateView(
                state: .empty("No recent trips to display."),
                retryAction: nil
            )
            .frame(height: 300)
        }
    }
    .background(KiaDesign.Colors.background)
}