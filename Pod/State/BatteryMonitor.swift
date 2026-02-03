//
//  BatteryMonitor.swift
//  Pod
//

import Foundation
import IOKit.ps
import Combine

class BatteryMonitor: ObservableObject {
    static let shared = BatteryMonitor()

    @Published var batteryLevel: Int = 100
    @Published var isCharging: Bool = false
    @Published var hasBattery: Bool = false

    private var timer: Timer?

    private init() {
        updateBatteryInfo()
        startMonitoring()
    }

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateBatteryInfo()
        }
    }

    func updateBatteryInfo() {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array

        guard !sources.isEmpty else {
            hasBattery = false
            batteryLevel = 100
            isCharging = false
            return
        }

        for source in sources {
            if let info = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any] {
                if let type = info[kIOPSTypeKey] as? String, type == kIOPSInternalBatteryType {
                    hasBattery = true

                    if let capacity = info[kIOPSCurrentCapacityKey] as? Int {
                        batteryLevel = capacity
                    }

                    if let charging = info[kIOPSIsChargingKey] as? Bool {
                        isCharging = charging
                    }
                    return
                }
            }
        }

        hasBattery = false
        batteryLevel = 100
    }

    deinit {
        timer?.invalidate()
    }
}
