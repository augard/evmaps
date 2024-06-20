//
//  DataRowView.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 20.06.2024.
//  Copyright © 2024 Apple. All rights reserved.
//

import SwiftUI

enum IconName: String {
    case car
    case charger = "ev.charger"
    case battery = "minus.plus.and.fluid.batteryblock"
    case clock
}

struct DataRowView<Content: View>: View {
    var icon: IconName
    var label: String
    var content: Content
    
    init(icon: IconName, label: String, content: () -> Content) {
        self.icon = icon
        self.label = label
        self.content = content()
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon.rawValue)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)

                    content
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .frame(minHeight: 44)
    }
}

struct DataProgressRowView: View {
    var icon: IconName
    var label: String
    var value: Double
    
    init(icon: IconName, label: String, value: Double) {
        self.icon = icon
        self.label = label
        self.value = value
    }
    
    var body: some View {
        DataRowView(icon: icon, label: label) {
            ProgressView(value: value)
                .frame(height: 10)
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        DataRowView(
            icon: .battery,
            label: "Simple",
            content: { Text("Text value") }
        )
        DataProgressRowView(
            icon: .battery,
            label: "Progress",
            value: 0.8
        )
        
        Spacer()
    }
    .padding()
}
