import Foundation

/// Headless CLI Command Runner for Terminal usage (`macopt` / `MacOptimizer status|clean|purge-ram|version|--help`).
public struct CLICommandRunner {
    
    public static func shouldHandleCLI(arguments: [String] = CommandLine.arguments) -> Bool {
        guard arguments.count > 1 else { return false }
        let firstArg = arguments[1]
        // Filter out macOS Finder Process Serial Number arguments and test runners
        if firstArg.starts(with: "-psn") || firstArg.contains("xctest") || firstArg.hasSuffix(".xctest") {
            return false
        }
        return true
    }
    
    public static func runCLI() async {
        let args = Array(CommandLine.arguments.dropFirst())
        let command = args.first?.lowercased() ?? "--help"
        
        switch command {
        case "status":
            await printSystemStatus()
            
        case "clean":
            let isDryRun = args.contains("--dry-run") || !args.contains("--execute")
            await runJunkClean(dryRun: isDryRun)
            
        case "purge-ram":
            await runRAMPurge()
            
        case "version", "-v", "--version":
            printVersion()
            
        case "help", "-h", "--help":
            printHelp()
            
        default:
            print("⚠️ Bilinmeyen komut: \(command)")
            printHelp()
            exit(1)
        }
        
        exit(0)
    }
    
    private static func printSystemStatus() async {
        let mem = await SystemMonitorService.shared.fetchMemoryStats()
        let cpu = await SystemMonitorService.shared.fetchCPUStats()
        let disk = await SystemMonitorService.shared.fetchDiskStats()
        let batt = await SystemMonitorService.shared.fetchBatteryStats()
        let hw = await SystemMonitorService.shared.fetchHardwareInfo()
        
        print("""
        ========================================================
        ⚡ MacOptimizer Pro System Status
        ========================================================
        💻 Donanım:      \(hw.modelName) (\(hw.chipName))
        🍏 macOS:        \(hw.osVersion)
        ⏱️  Çalışma:      \(hw.uptimeString)
        
        🧠 RAM Kullanım: \(ByteFormatter.formatMemory(mem.actualUsedBytes)) / \(ByteFormatter.formatMemory(mem.totalBytes)) (%\(Int(mem.usedPercentage * 100)))
        📊 RAM Baskısı:  \(mem.pressureLevel.rawValue)
        💾 Swap Takas:   \(ByteFormatter.formatMemory(mem.swapUsedBytes)) / \(ByteFormatter.formatMemory(mem.swapTotalBytes))
        
        🔥 CPU Kullanım: %\(String(format: "%.1f", cpu.totalUsage)) (\(cpu.physicalCores) Çekirdek)
        🌡️ Termal Durum: \(cpu.thermalState.rawValue)
        
        💽 Disk Alanı:   \(ByteFormatter.format(disk.usedBytes)) Kullanılan / \(ByteFormatter.format(disk.freeBytes)) Boş
        🔋 Pil Durumu:   %\(batt.percentage) (\(batt.powerSource))
        ========================================================
        """)
    }
    
    private static func runJunkClean(dryRun: Bool) async {
        print("🔍 Gereksiz dosyalar ve önbellekler taranıyor...")
        let groups = await JunkCleanerService.shared.scanAll()
        let plan = await JunkCleanerService.shared.generateCleaningPlan(from: groups)
        
        print("\n📊 Bulunan Gereksiz Dosyalar:")
        print("--------------------------------------------------------")
        for group in groups {
            let totalGroupBytes = group.items.reduce(0) { $0 + $1.sizeBytes }
            print("• \(group.type.title): \(group.items.count) öğe (\(ByteFormatter.format(totalGroupBytes)))")
        }
        print("--------------------------------------------------------")
        print("Toplam Kurtarılabilir Alan: \(ByteFormatter.format(plan.selectedEstimatedBytes))")
        print("Maksimum Risk Derecesi:   \(plan.maxRiskLevel.displayName)")
        print("Zero-Harm Güvenlik:       Aktif (Sistem kök yolları korumalı)")
        
        if dryRun {
            print("\n💡 Bilgi: Bu bir önizleme (Dry-Run) çalıştırmasıydı. Temizliği gerçekleştirmek için:")
            print("   MacOptimizer clean --execute")
        } else {
            print("\n🚀 Temizlik başlatılıyor...")
            let result = await JunkCleanerService.shared.executeCleaningPlan(plan)
            print("✨ Temizlik tamamlandı! \(ByteFormatter.format(result.totalFreedBytes)) alan başarıyla geri kazanıldı.")
        }
    }
    
    private static func runRAMPurge() async {
        print("🧹 Inactive RAM önbellekleri güvenle boşaltılıyor...")
        let result = await MemoryOptimizerService.shared.purgeMemory()
        print("✨ Başarılı! \(ByteFormatter.formatMemory(result.freedBytes)) RAM alanı serbest bırakıldı.")
    }
    
    private static func printVersion() {
        print("MacOptimizer Pro v2.4.0 (Zero-Harm Defense-in-Depth Native macOS Toolkit)")
        print("Apache License 2.0 • https://github.com/Codifya/MacOptimizer")
    }
    
    private static func printHelp() {
        print("""
        MacOptimizer Pro CLI Yardım & Kullanım Kılavuzu:
        
        Kullanım:
          MacOptimizer <komut> [seçenekler]
        
        Komutlar:
          status           Anlık CPU, RAM, Termal Durum, Swap ve Disk telemetrisini yazdırır.
          clean            Gereksiz dosya taraması yapar (Varsayılan: --dry-run).
          clean --execute  Bulunan gereksiz önbellekleri Zero-Harm politikalarıyla temizler.
          purge-ram        Pasif sistem önbelleklerini temizleyerek RAM boşaltır.
          version          Sürüm ve lisans bilgisini görüntüler.
          help             Bu yardım menüsünü görüntüler.
        
        Örnekler:
          MacOptimizer status
          MacOptimizer clean --dry-run
          MacOptimizer purge-ram
        """)
    }
}
