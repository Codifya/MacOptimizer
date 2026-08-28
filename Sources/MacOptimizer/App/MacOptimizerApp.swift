import SwiftUI
import AppKit

@main
struct MacOptimizerApp: App {
    @StateObject private var appState = AppState.shared
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    
    var body: some Scene {
        // Main Application Window
        WindowGroup {
            MainView()
                .preferredColorScheme(nil) // Respect system dark/light mode
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .help) {
                Button("MacOptimizer Yardımı") {
                    if let url = URL(string: "https://apple.com") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        
        // Menu Bar Extra for fast access
        MenuBarExtra("MacOptimizer", systemImage: "bolt.shield") {
            MenuBarView(appState: appState)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Popover View inside the Menu Bar Extra
struct MenuBarView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("MacOptimizer", systemImage: "bolt.shield.fill")
                    .font(.system(size: 14, weight: .bold))
                
                Spacer()
                
                MetricBadge(text: appState.memoryStats.pressureLevel.rawValue, colorName: appState.memoryStats.pressureLevel.colorName)
            }
            
            Divider()
            
            // RAM Status
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RAM Kullanımı")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("\(ByteFormatter.formatMemory(appState.memoryStats.actualUsedBytes)) / \(ByteFormatter.formatMemory(appState.memoryStats.totalBytes))")
                        .font(.system(size: 13, weight: .bold))
                }
                
                Spacer()
                
                Text(String(format: "%.0f%%", appState.memoryStats.usedPercentage * 100))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
            }
            
            AnimatedProgressBar(progress: appState.memoryStats.usedPercentage, gradient: SystemTheme.memoryGradient, height: 6)
            
            HStack(spacing: 8) {
                ActionButton(
                    title: appState.isPurgingMemory ? "Boşaltılıyor..." : "RAM Boşalt",
                    iconName: "memorychip.fill",
                    gradient: SystemTheme.memoryGradient,
                    isLoading: appState.isPurgingMemory
                ) {
                    appState.purgeRAM()
                }
                
                Button("Uygulamayı Aç") {
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            Divider()
            
            HStack {
                Text("\(appState.hardwareInfo.chipName) • \(appState.hardwareInfo.uptimeString)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Çıkış") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.red)
            }
        }
        .padding(14)
        .frame(width: 280)
        .background(.ultraThinMaterial)
    }
}
