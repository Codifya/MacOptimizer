import SwiftUI
import AppKit

@main
struct MacOptimizerMain {
    static func main() async {
        if CLICommandRunner.shouldHandleCLI() {
            await CLICommandRunner.runCLI()
            exit(0)
        } else {
            MacOptimizerApp.main()
        }
    }
}

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
                Button(L10n.string("MacOptimizer GitHub Repository")) {
                    if let url = URL(string: "https://github.com/Codifya/MacOptimizer") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        
        // Menu Bar Extra for fast access
        MenuBarExtra("MacOptimizer", systemImage: "bolt.shield.fill") {
            MenuBarView(appState: appState, metrics: appState.metrics)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Rich interactive popover view inside the macOS Menu Bar Extra
struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var metrics: LiveMetricsStore
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.shield.fill")
                        .foregroundColor(.blue)
                    Text("MacOptimizer Pro")
                        .font(.system(size: 13, weight: .bold))
                }
                
                Spacer()
                
                MetricBadge(
                    text: metrics.cpuStats.thermalState.localizedTitle,
                    colorName: metrics.cpuStats.thermalState.colorName
                )
            }
            
            Divider()
            
            // 1. RAM Metric Row
            VStack(spacing: 4) {
                HStack {
                    Text(l10n: "RAM")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(ByteFormatter.formatMemory(metrics.memoryStats.actualUsedBytes)) (\(Int(metrics.memoryStats.usedPercentage * 100))%)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                }
                
                AnimatedProgressBar(progress: metrics.memoryStats.usedPercentage, gradient: SystemTheme.memoryGradient, height: 5)
            }
            
            // 2. CPU Metric Row
            VStack(spacing: 4) {
                HStack {
                    Text(l10n: "Processor (CPU)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f%%", metrics.cpuStats.totalUsage))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                }
                
                AnimatedProgressBar(progress: metrics.cpuStats.totalUsage / 100.0, gradient: SystemTheme.primaryGradient, height: 5)
            }
            
            // 3. Disk Metric Row
            HStack {
                Text(l10n: "Free Disk:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(ByteFormatter.format(metrics.diskStats.freeBytes))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.purple)
            }
            
            Divider()
            
            // App controls
            HStack(spacing: 8) {
                Button(L10n.string("Open Main Window")) {
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Divider()
            
            // Footer
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(appState.autonomousConfig.isWatchdogActive ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                    Text(l10n: appState.autonomousConfig.isWatchdogActive ? "Autonomous Protection Active" : "Autonomous Protection Off")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(L10n.string("Quit")) {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.red)
            }
        }
        .padding(14)
        .frame(width: 290)
        .background(.ultraThinMaterial)
    }
}
