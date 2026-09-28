import Foundation
import AppKit
import Darwin
import IOKit.ps

/// High-performance system monitor using Darwin Mach APIs, sysctl, and IOKit.
/// Optimized for ultra-low CPU consumption, caching, and battery efficiency.
public actor SystemMonitorService: SystemMetricsSampling {
    public static let shared = SystemMonitorService()
    
    /// `mach_host_self()` returns a new send right on every call; calling it per tick leaks port
    /// references (a slow, unbounded kernel-side leak over long sessions). Acquire it exactly once.
    private static let hostPort: mach_port_t = mach_host_self()
    
    /// Static hardware identity — computed once instead of 2–4 sysctl calls + string work per tick.
    private static let processorName: String = SystemMonitorService.readProcessorName()
    private static let modelIdentifier: String = SystemMonitorService.readModelIdentifier()
    private static let osVersionString: String = {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }()
    
    private var lastCPULoadInfo: host_cpu_load_info?
    private var cachedProcesses: [ProcessInfoModel] = []
    private var lastProcessFetchTime: Date?
    private var lastNetworkSampleTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    private var lastTotalInBytes: UInt64 = 0
    private var lastTotalOutBytes: UInt64 = 0
    
    public init() {}
    
    // MARK: - Memory Statistics (Mach VM - In-Memory < 0.05ms)
    public func fetchMemoryStats() -> MemoryStats {
        var stats = MemoryStats()
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        stats.totalBytes = totalMemory
        
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(Self.hostPort, HOST_VM_INFO64, $0, &count)
            }
        }
        
        let pageSize = UInt64(getpagesize())
        
        if result == KERN_SUCCESS {
            let free = UInt64(vmStats.free_count) * pageSize
            let active = UInt64(vmStats.active_count) * pageSize
            let inactive = UInt64(vmStats.inactive_count) * pageSize
            let wire = UInt64(vmStats.wire_count) * pageSize
            let compressed = UInt64(vmStats.compressor_page_count) * pageSize
            let speculative = UInt64(vmStats.speculative_count) * pageSize
            
            stats.freeBytes = free + speculative
            stats.activeBytes = active
            stats.inactiveBytes = inactive
            stats.wiredBytes = wire
            stats.compressedBytes = compressed
            stats.appMemoryBytes = active + wire
            
            let usedPages = active + wire + compressed
            let memoryPressure = Swift.min(1.0, Swift.max(0.0, Double(usedPages) / Double(Swift.max(1, totalMemory))))
            stats.memoryPressure = memoryPressure
            
            if memoryPressure > 0.85 {
                stats.pressureLevel = .critical
            } else if memoryPressure > 0.70 {
                stats.pressureLevel = .warning
            } else {
                stats.pressureLevel = .normal
            }
        }
        
        // Read Swap Memory via sysctl vm.swapusage
        var swapUsage = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swapUsage, &swapSize, nil, 0) == 0 {
            stats.swapTotalBytes = swapUsage.xsu_total
            stats.swapUsedBytes = swapUsage.xsu_used
            stats.swapFreeBytes = swapUsage.xsu_avail
        }
        
        return stats
    }
    
    // MARK: - CPU Statistics (< 0.05ms)
    public func fetchCPUStats() -> CPUStats {
        var cpuStats = CPUStats()
        
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var cpuLoad = host_cpu_load_info()
        
        let result = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(Self.hostPort, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            if let last = lastCPULoadInfo {
                let userDelta = Double(cpuLoad.cpu_ticks.0 - last.cpu_ticks.0)
                let sysDelta = Double(cpuLoad.cpu_ticks.1 - last.cpu_ticks.1)
                let idleDelta = Double(cpuLoad.cpu_ticks.2 - last.cpu_ticks.2)
                let niceDelta = Double(cpuLoad.cpu_ticks.3 - last.cpu_ticks.3)
                
                let totalDelta = Swift.max(1.0, userDelta + sysDelta + idleDelta + niceDelta)
                
                cpuStats.userUsage = Swift.max(0.0, Swift.min(100.0, (userDelta / totalDelta) * 100.0))
                cpuStats.systemUsage = Swift.max(0.0, Swift.min(100.0, (sysDelta / totalDelta) * 100.0))
                cpuStats.idleUsage = Swift.max(0.0, Swift.min(100.0, (idleDelta / totalDelta) * 100.0))
                cpuStats.totalUsage = Self.sampledCPUUsage(previous: [last.cpu_ticks.0, last.cpu_ticks.1, last.cpu_ticks.2, last.cpu_ticks.3].map(UInt64.init), current: [cpuLoad.cpu_ticks.0, cpuLoad.cpu_ticks.1, cpuLoad.cpu_ticks.2, cpuLoad.cpu_ticks.3].map(UInt64.init)) ?? 0
            } else {
                cpuStats.totalUsage = 0
                cpuStats.idleUsage = 0
            }
            lastCPULoadInfo = cpuLoad
        }
        
        cpuStats.physicalCores = ProcessInfo.processInfo.activeProcessorCount
        cpuStats.logicalCores = ProcessInfo.processInfo.processorCount
        cpuStats.processorName = Self.processorName
        
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: cpuStats.thermalState = .nominal
        case .fair: cpuStats.thermalState = .fair
        case .serious: cpuStats.thermalState = .serious
        case .critical: cpuStats.thermalState = .critical
        @unknown default: cpuStats.thermalState = .nominal
        }
        
        return cpuStats
    }
    
    // MARK: - Disk Statistics
    public func fetchDiskStats() -> DiskStats {
        var stats = DiskStats()
        let fileURL = URL(fileURLWithPath: "/")
        
        do {
            let values = try fileURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeNameKey
            ])
            
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let free = Int64(values.volumeAvailableCapacityForImportantUsage ?? Int64(values.volumeAvailableCapacity ?? 0))
            let used = Swift.max(0, total - free)
            
            stats.totalBytes = total
            stats.freeBytes = free
            stats.usedBytes = used
            stats.volumeName = values.volumeName ?? "Macintosh HD"
        } catch {
            if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") {
                let total = (attrs[.systemSize] as? NSNumber)?.int64Value ?? 0
                let free = (attrs[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
                stats.totalBytes = total
                stats.freeBytes = free
                stats.usedBytes = Swift.max(0, total - free)
            }
        }
        
        return stats
    }
    
    // MARK: - Battery Statistics (IOKit)
    public func fetchBatteryStats() -> BatteryStats {
        var stats = BatteryStats()
        
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return stats
        }
        
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            
            stats.isPresent = true
            
            if let curCap = description[kIOPSCurrentCapacityKey as String] as? Int,
               let maxCap = description[kIOPSMaxCapacityKey as String] as? Int, maxCap > 0 {
                let calculated = Int((Double(curCap) / Double(maxCap)) * 100.0)
                stats.percentage = Swift.min(100, Swift.max(0, calculated))
            }
            
            if let isCharging = description[kIOPSIsChargingKey as String] as? Bool {
                stats.isCharging = isCharging
            }
            
            if let isCharged = description[kIOPSIsChargedKey as String] as? Bool {
                stats.isCharged = isCharged
            }
            
            if let powerSource = description[kIOPSPowerSourceStateKey as String] as? String {
                stats.powerSource = (powerSource == kIOPSACPowerValue as String) ? "AC Adaptör" : "Pil"
            }
            
            if let timeRemaining = description[kIOPSTimeToEmptyKey as String] as? Int, timeRemaining > 0 {
                let hours = timeRemaining / 60
                let mins = timeRemaining % 60
                stats.timeRemainingFormatted = "\(hours) sa \(mins) dk kaldı"
            } else if stats.isCharging {
                if let timeToFull = description[kIOPSTimeToFullChargeKey as String] as? Int, timeToFull > 0 {
                    let hours = timeToFull / 60
                    let mins = timeToFull % 60
                    stats.timeRemainingFormatted = "Dolmasına: \(hours) sa \(mins) dk"
                } else {
                    stats.timeRemainingFormatted = "Şarj Oluyor"
                }
            } else {
                stats.timeRemainingFormatted = "Hesaplanıyor..."
            }
            
            break
        }
        
        // IOKit AppleSmartBattery Inspection
        let matching = IOServiceMatching("AppleSmartBattery")
        var iterator: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS {
            let service = IOIteratorNext(iterator)
            if service != 0 {
                var propsRef: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                   let props = propsRef?.takeRetainedValue() as? [String: Any] {
                    if let cycles = props["CycleCount"] as? Int {
                        stats.cycleCount = cycles
                    }
                    if let temp = props["Temperature"] as? Int {
                        let tempC = (temp > 1000) ? (Double(temp) / 100.0) : (Double(temp) / 10.0 - 273.15)
                        stats.temperatureCelsius = Swift.max(0.0, Swift.min(100.0, tempC))
                    }
                    if props["AppleRawMaxCapacity"] is Int || props["NominalChargeCapacity"] is Int || props["MaxCapacity"] is Int {
                        stats.designCapacityMah = props["DesignCapacity"] as? Int ?? 0
                        stats.healthPercentage = Self.batteryHealthPercentage(properties: props.compactMapValues { $0 as? Int })
                    }
                    if let isPermanentFail = props["PermanentFailureStatus"] as? Int, isPermanentFail != 0 {
                        stats.condition = "Servis Öneriliyor"
                    } else if stats.healthPercentage < 80 {
                        stats.condition = "Pil Sağlığı Zayıf"
                    } else {
                        stats.condition = "Normal"
                    }
                }
                IOObjectRelease(service)
            }
            IOObjectRelease(iterator)
        }
        
        return stats
    }

    static func batteryHealthPercentage(properties: [String: Int]) -> Int {
        if let capacity = properties["AppleRawMaxCapacity"] ?? properties["NominalChargeCapacity"],
           let design = properties["DesignCapacity"], design > 0 {
            return min(100, max(0, Int((Double(capacity) / Double(design) * 100).rounded())))
        }
        guard let maxCapacity = properties["MaxCapacity"] else { return 0 }
        if (0...100).contains(maxCapacity) { return maxCapacity }
        guard let design = properties["DesignCapacity"], design > 0 else { return 0 }
        return min(100, max(0, Int((Double(maxCapacity) / Double(design) * 100).rounded())))
    }

    static func sampledCPUUsage(previous: [UInt64], current: [UInt64]) -> Double? {
        guard previous.count == 4, current.count == 4,
              zip(previous, current).allSatisfy({ $1 >= $0 }) else { return nil }
        let deltas = zip(previous, current).map { Double($1 - $0) }
        let total = deltas.reduce(0, +)
        guard total > 0 else { return nil }
        return min(100, max(0, ((deltas[0] + deltas[1] + deltas[3]) / total) * 100))
    }
    
    // MARK: - Hardware Information
    public func fetchHardwareInfo() -> HardwareInfo {
        var info = HardwareInfo()
        
        info.chipName = Self.processorName
        info.modelName = Self.modelIdentifier
        info.memorySizeFormatted = ByteFormatter.formatMemory(ProcessInfo.processInfo.physicalMemory)
        info.osVersion = Self.osVersionString
        
        info.uptimeString = getSystemUptime()
        
        return info
    }
    
    // MARK: - Network Throughput & Interface Statistics (Darwin getifaddrs)
    public func fetchNetworkStats() -> NetworkStats {
        var stats = NetworkStats()
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return stats
        }
        defer { freeifaddrs(ifaddr) }
        
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        var activeInterface = "en0"
        var ipAddr = "127.0.0.1"
        
        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            let name = String(cString: current.pointee.ifa_name)
            let flags = Int32(current.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) == IFF_UP
            let isRunning = (flags & IFF_RUNNING) == IFF_RUNNING
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK
            
            if isUp && isRunning && !isLoopback {
                if let sa = current.pointee.ifa_addr {
                    if sa.pointee.sa_family == UInt8(AF_LINK) {
                        if let data = current.pointee.ifa_data {
                            let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                            totalIn += UInt64(networkData.ifi_ibytes)
                            totalOut += UInt64(networkData.ifi_obytes)
                            activeInterface = name
                        }
                    } else if sa.pointee.sa_family == UInt8(AF_INET) {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(sa, socklen_t(sa.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                            ipAddr = hostname.withUnsafeBufferPointer { ptr in
                                ptr.baseAddress != nil ? String(cString: ptr.baseAddress!) : "127.0.0.1"
                            }
                        }
                    }
                }
            }
            
            ptr = current.pointee.ifa_next
        }
        
        let currentTime = CFAbsoluteTimeGetCurrent()
        let elapsed = currentTime - lastNetworkSampleTime
        
        if elapsed > 0.1 && lastTotalInBytes > 0 && totalIn >= lastTotalInBytes {
            stats.downloadBytesPerSec = Double(totalIn - lastTotalInBytes) / elapsed
            stats.uploadBytesPerSec = Double(totalOut - lastTotalOutBytes) / elapsed
        }
        
        lastNetworkSampleTime = currentTime
        lastTotalInBytes = totalIn
        lastTotalOutBytes = totalOut
        
        stats.totalDownloadBytes = totalIn
        stats.totalUploadBytes = totalOut
        stats.activeInterfaceName = activeInterface
        stats.localIPAddress = ipAddr
        
        return stats
    }
    
    // MARK: - Running Processes Scanner (Optimized with short-term cache)
    /// Spawns `/bin/ps` (setuid on macOS, the only unprivileged way to read RSS/CPU of root-owned
    /// processes such as WindowServer). Callers control the cadence through `MonitoringCoordinator`;
    /// the short cache only deduplicates bursts of manual refreshes.
    public func fetchRunningProcesses(forceRefresh: Bool = false) async -> [ProcessInfoModel] {
        if !forceRefresh,
           let lastTime = lastProcessFetchTime,
           Date().timeIntervalSince(lastTime) < 1.5,
           !cachedProcesses.isEmpty {
            return cachedProcesses
        }
        return await sampleProcessList() ?? cachedProcesses
    }
    
    private func sampleProcessList() async -> [ProcessInfoModel]? {
        let runningApps = NSWorkspace.shared.runningApplications // documented thread-safe
        var appDict: [pid_t: NSRunningApplication] = [:]
        appDict.reserveCapacity(runningApps.count)
        for app in runningApps {
            appDict[app.processIdentifier] = app
        }
        
        // Trailing "=" suppresses the header line. Output is ~60–120 KB on a busy Mac, which the
        // old runner could not drain (64 KB pipe buffer deadlock); ProcessExecutor streams it.
        let result = await SystemCommandRunner.run(
            executable: "/bin/ps",
            arguments: ["-axo", "pid=,rss=,%cpu=,comm="],
            timeoutSeconds: 3.0,
            outputLimit: 2 * 1024 * 1024
        )
        guard result.isSuccess else { return nil }
        
        var processes: [ProcessInfoModel] = []
        processes.reserveCapacity(cachedProcesses.count + 16)
        
        for line in result.standardOutput.split(separator: "\n", omittingEmptySubsequences: true) {
            let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count >= 4,
                  let pid = Int32(parts[0]),
                  let rssKB = UInt64(parts[1]),
                  let cpu = Double(parts[2]) else {
                continue
            }
            
            let path = String(parts[3])
            let runningApp = appDict[pid]
            let name = runningApp?.localizedName ?? String(path.split(separator: "/").last ?? Substring(path))
            
            processes.append(ProcessInfoModel(
                pid: pid,
                name: name,
                path: path,
                memoryBytes: rssKB * 1024,
                cpuPercentage: cpu,
                isUserApp: runningApp != nil,
                bundleIdentifier: runningApp?.bundleIdentifier,
                isProtected: !SafetyGuard.isProcessKillable(pid: pid, name: name, path: path)
            ))
        }
        
        processes.sort { $0.memoryBytes > $1.memoryBytes }
        self.cachedProcesses = processes
        self.lastProcessFetchTime = Date()
        return processes
    }
    
    // MARK: - SystemMetricsSampling
    public func sampleCore() -> (MemoryStats, CPUStats, NetworkStats) {
        (fetchMemoryStats(), fetchCPUStats(), fetchNetworkStats())
    }
    
    public func sampleDisk() -> DiskStats { fetchDiskStats() }
    public func sampleBattery() -> BatteryStats { fetchBatteryStats() }
    public func sampleHardware() -> HardwareInfo { fetchHardwareInfo() }
    public func sampleProcesses() async -> [ProcessInfoModel]? { await sampleProcessList() }
    
    // MARK: - Internal Helpers
    private static func readProcessorName() -> String {
        var size: size_t = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        if size > 0 {
            var brand = [CChar](repeating: 0, count: size)
            sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
            let brandStr = String(decoding: brand.map { UInt8(bitPattern: $0) }, as: UTF8.self).trimmingCharacters(in: CharacterSet(charactersIn: "\0 \n\r\t"))
            if !brandStr.isEmpty {
                return brandStr
            }
        }
        
        var chipModelSize: size_t = 0
        sysctlbyname("hw.chip_model", nil, &chipModelSize, nil, 0)
        if chipModelSize > 0 {
            var chip = [CChar](repeating: 0, count: chipModelSize)
            sysctlbyname("hw.chip_model", &chip, &chipModelSize, nil, 0)
            let chipStr = String(decoding: chip.map { UInt8(bitPattern: $0) }, as: UTF8.self).trimmingCharacters(in: CharacterSet(charactersIn: "\0 \n\r\t"))
            if !chipStr.isEmpty {
                return chipStr
            }
        }
        
        #if arch(arm64)
        return "Apple Silicon"
        #else
        return "Intel Processor"
        #endif
    }
    
    private static func readModelIdentifier() -> String {
        var size: size_t = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "Mac" }
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let modelStr = String(decoding: model.map { UInt8(bitPattern: $0) }, as: UTF8.self).trimmingCharacters(in: CharacterSet(charactersIn: "\0 \n\r\t"))
        return modelStr.isEmpty ? "Mac" : modelStr
    }
    
    private func getSystemUptime() -> String {
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.size
        var mib = [CTL_KERN, KERN_BOOTTIME]
        
        if sysctl(&mib, 2, &bootTime, &size, nil, 0) != -1 {
            let bootTimestamp = Date(timeIntervalSince1970: Double(bootTime.tv_sec))
            let uptime = Date().timeIntervalSince(bootTimestamp)
            
            let days = Int(uptime) / 86400
            let hours = (Int(uptime) % 86400) / 3600
            let minutes = (Int(uptime) % 3600) / 60
            
            if days > 0 {
                return "\(days) gün, \(hours) saat"
            } else if hours > 0 {
                return "\(hours) saat, \(minutes) dk"
            } else {
                return "\(minutes) dakika"
            }
        }
        return "Bilinmiyor"
    }
}
