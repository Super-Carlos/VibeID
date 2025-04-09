// Vibe_IDApp.swift
// Vibe ID
//
// Created by Studio Carlos in 2025.
// Copyright (C) 2025 Studio Carlos
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import SwiftUI
import Network
import OSCKit

@main
struct Vibe_IDApp: App {
    // Network connectivity state
    @StateObject private var networkMonitor = NetworkMonitor()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(networkMonitor)
                .onAppear {
                    // Initialize all services at startup
                    print("Application started")
                    
                    // Enable network monitoring for OSC
                    networkMonitor.startMonitoring()
                    
                    // Send an OSC message to signal the application's startup
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                        await sendAppStartedMessage()
                    }
                }
                .onDisappear {
                    // Clean up when the application closes
                    networkMonitor.stopMonitoring()
                }
        }
    }
}

// Function to send an OSC message at startup
@MainActor
func sendAppStartedMessage() async {
    print("Sending initial OSC message after startup...")
    
    let settingsManager = SettingsManager.shared
    let oscManager = OSCManager() // Direct initialization without causing conflict
    
    if settingsManager.hasValidOSCConfig {
        print("Valid OSC configuration, sending message...")
        
        // Only send messages in standard format
        oscManager.send(
            OSCKit.OSCMessage(OSCKit.OSCAddressPattern("/vibeid/status"), values: ["app_started"]),
            to: settingsManager.oscHost,
            port: settingsManager.oscPort
        )
        
        // Also send a test ping
        oscManager.send(
            OSCKit.OSCMessage(OSCKit.OSCAddressPattern("/vibeid/test"), values: ["ping"]),
            to: settingsManager.oscHost,
            port: settingsManager.oscPort
        )
        
        print("Startup OSC messages sent!")
    } else {
        print("Invalid OSC configuration, no message sent.")
    }
}

// Class to monitor network state
class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = false
    @Published var connectionType = ConnectionType.unknown
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    func startMonitoring() {
        print("Starting network monitoring")
        
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isConnected = path.status == .satisfied
                
                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                    print("Network: Connected via WiFi")
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                    print("Network: Connected via cellular")
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .ethernet
                    print("Network: Connected via Ethernet")
                } else {
                    self.connectionType = .unknown
                    print("Network: Unknown connection type")
                }
                
                // Log available interfaces
                print("Network: Path status \(path.status)")
                print("Network: Available gateways: \(path.gateways.count)")
            }
        }
        
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
        print("Network monitoring stopped")
    }
}
