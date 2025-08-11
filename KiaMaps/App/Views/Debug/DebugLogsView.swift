//
//  DebugLogsView.swift
//  KiaMaps
//
//  Created by Claude on 11.08.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import SwiftUI

struct DebugLogsView: View {
    @StateObject private var server = RemoteLoggingServer.shared
    @State private var showingExportSheet = false
    @State private var exportedText = ""
    @State private var autoScroll = true
    @Namespace private var bottomID
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Status bar
                statusBar
                
                // Filters
                filterBar
                
                Divider()
                
                // Logs list
                if server.filteredLogs.isEmpty {
                    emptyState
                } else {
                    logsList
                }
            }
            .navigationTitle("Debug Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    serverToggleButton
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        clearButton
                        exportButton
                    }
                }
            }
        }
        .onAppear {
            if !server.isRunning {
                server.start()
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            ShareSheet(items: [exportedText])
        }
    }
    
    // MARK: - Components
    
    private var statusBar: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(server.isRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(server.isRunning ? "Server Running" : "Server Stopped")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if server.connectionCount > 0 {
                Label("\(server.connectionCount)", systemImage: "network")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text("\(server.filteredLogs.count) logs")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    private var filterBar: some View {
        VStack(spacing: 12) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search logs...", text: $server.filterText)
                    .textFieldStyle(.plain)
                
                if !server.filterText.isEmpty {
                    Button {
                        server.filterText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(8)
            
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Level filter
                    FilterChipMenu(
                        title: "Level",
                        selection: $server.selectedLevel,
                        options: LogEntry.LogLevel.allCases,
                        optionLabel: { $0?.rawValue ?? "All" },
                        optionIcon: { $0?.symbolName }
                    )
                    
                    // Source filter
                    FilterChipMenu(
                        title: "Source",
                        selection: $server.selectedSource,
                        options: [nil] + LogEntry.LogSource.allCases.map { $0 as LogEntry.LogSource? },
                        optionLabel: { $0?.rawValue ?? "All" }
                    )
                    
                    // Category filter
                    if !server.availableCategories.isEmpty {
                        FilterChipMenu(
                            title: "Category",
                            selection: $server.selectedCategory,
                            options: [nil] + server.availableCategories.map { $0 as String? },
                            optionLabel: { $0 ?? "All" }
                        )
                    }
                    
                    // Auto-scroll toggle
                    Toggle(isOn: $autoScroll) {
                        Label("Auto-scroll", systemImage: "arrow.down.circle")
                    }
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    private var logsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(server.filteredLogs) { log in
                        LogRowView(log: log)
                        Divider()
                    }
                    
                    Color.clear
                        .frame(height: 1)
                        .id(bottomID)
                }
            }
            .onChange(of: server.filteredLogs.count) { _, _ in
                if autoScroll {
                    withAnimation {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No logs")
                .font(.headline)
            
            if !server.filterText.isEmpty || server.selectedLevel != nil || 
               server.selectedSource != nil || server.selectedCategory != nil {
                Text("Try adjusting your filters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button("Clear Filters") {
                    server.filterText = ""
                    server.selectedLevel = nil
                    server.selectedSource = nil
                    server.selectedCategory = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else if !server.isRunning {
                Text("Start the server to receive logs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Waiting for logs from extensions...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Toolbar Items
    
    private var serverToggleButton: some View {
        Button {
            if server.isRunning {
                server.stop()
            } else {
                server.start()
            }
        } label: {
            Label(
                server.isRunning ? "Stop" : "Start",
                systemImage: server.isRunning ? "stop.circle" : "play.circle"
            )
        }
    }
    
    private var clearButton: some View {
        Button {
            server.clearLogs()
        } label: {
            Image(systemName: "trash")
        }
        .disabled(server.logs.isEmpty)
    }
    
    private var exportButton: some View {
        Button {
            exportedText = server.exportLogs()
            showingExportSheet = true
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .disabled(server.logs.isEmpty)
    }
}

// MARK: - Log Row View

struct LogRowView: View {
    let log: LogEntry
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Main log line
            HStack(alignment: .top, spacing: 8) {
                // Level indicator
                Text(log.level.symbolName)
                    .font(.system(size: 14))
                
                VStack(alignment: .leading, spacing: 2) {
                    // Header
                    HStack(spacing: 4) {
                        Text(log.formattedTimestamp)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                        
                        Text("[\(log.source.rawValue)]")
                            .font(.system(size: 11))
                            .foregroundStyle(.blue)
                        
                        Text("[\(log.category)]")
                            .font(.system(size: 11))
                            .foregroundStyle(.purple)
                        
                        if let location = log.formattedLocation {
                            Text(location)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Message
                    Text(log.message)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .lineLimit(isExpanded ? nil : 2)
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(backgroundColorForLevel(log.level))
    }
    
    private func backgroundColorForLevel(_ level: LogEntry.LogLevel) -> Color {
        switch level {
        case .error, .fault:
            return Color.red.opacity(0.05)
        case .default:
            return Color.yellow.opacity(0.05)
        default:
            return Color.clear
        }
    }
}

// MARK: - Filter Chip Menu

struct FilterChipMenu<T: Equatable>: View {
    let title: String
    @Binding var selection: T?
    let options: [T?]
    let optionLabel: (T?) -> String
    var optionIcon: ((T?) -> String?)? = nil
    
    var body: some View {
        Menu {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Button {
                    selection = option
                } label: {
                    HStack {
                        if let icon = optionIcon?(option) {
                            Text(icon)
                        }
                        Text(optionLabel(option))
                        if selection == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                Text(optionLabel(selection))
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selection == nil ? Color.clear : Color.accentColor.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selection == nil ? Color.secondary.opacity(0.3) : Color.accentColor, lineWidth: 1)
            )
            .cornerRadius(8)
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}