//
//  MenuBar.swift
//  Pod
//

import SwiftUI

struct MenuBar: View {
    var title: String
    var isPlaying: Bool

    @StateObject private var battery = BatteryMonitor.shared

    private var batteryIcon: String {
        if battery.isCharging {
            return "battery.100percent.bolt"
        }
        switch battery.batteryLevel {
        case 0..<10: return "battery.0percent"
        case 10..<35: return "battery.25percent"
        case 35..<60: return "battery.50percent"
        case 60..<85: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    private var batteryColor: Color {
        if battery.isCharging { return .green }
        if battery.batteryLevel < 20 { return .red }
        return .green
    }

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.black)
                .fontWeight(.bold)

            Spacer()
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .foregroundColor(.blue)
            Image(systemName: batteryIcon)
                .foregroundColor(batteryColor)
        }
        .padding(7)
        .background(.menuBarGray)
        .border(Color.black, width: 1)
        .shadow(radius: 10)
    }
}
