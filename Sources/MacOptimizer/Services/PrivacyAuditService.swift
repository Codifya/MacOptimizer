import Foundation
import ApplicationServices

/// Model representing a single macOS security & privacy posture item
public struct SecurityPostureItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let detail: String
    public let isSecure: Bool
    public let statusText: String
    public let recommendation: String
    public let severity: SecuritySeverity
    
    public enum SecuritySeverity: String, Sendable, Equatable {
        case critical = "Kritik"
        case warning  = "Uyarı"
        case secure   = "Güvenli"

        /// Localized display label. Raw values are kept stable and must not be shown in the UI.
        public var localizedTitle: String {
            switch self {
            case .critical: return L10n.string("Critical", table: .services)
            case .warning:  return L10n.string("Warning", table: .services)
            case .secure:   return L10n.string("Secure", table: .services)
            }
        }
        
        public var badgeColor: String {
            switch self {
            case .critical: return "red"
            case .warning:  return "orange"
            case .secure:   return "green"
            }
        }
    }
}

/// Comprehensive macOS Security & Privacy Posture Audit Report
public struct SecurityAuditReport: Sendable, Equatable {
    public let score: Int
    public let items: [SecurityPostureItem]
    public let scannedDate: Date
    
    public var ratingDescription: String {
        switch score {
        case 90...100: return L10n.string("Excellent Security Shield", table: .services)
        case 70..<90:  return L10n.string("Good / Standard Security", table: .services)
        case 50..<70:  return L10n.string("Settings Need Improvement", table: .services)
        default:       return L10n.string("Critical Security Risk", table: .services)
        }
    }
    
    public var ratingColorName: String {
        switch score {
        case 80...100: return "green"
        case 60..<80:  return "orange"
        default:       return "red"
        }
    }
}

/// Service that audits macOS security settings, SIP status, Gatekeeper, and Firewall
public actor PrivacyAuditService {
    public static let shared = PrivacyAuditService()
    
    private let commandRunner: MaintenanceService.CommandRunner
    private let accessibilityChecker: @Sendable () -> Bool

    public init(
        commandRunner: @escaping MaintenanceService.CommandRunner = { executable, arguments in await SandboxedCommandRunner.run(executable: executable, arguments: arguments) },
        accessibilityChecker: @escaping @Sendable () -> Bool = { AXIsProcessTrusted() }
    ) {
        self.commandRunner = commandRunner
        self.accessibilityChecker = accessibilityChecker
    }
    
    /// Performs a full macOS security & privacy posture evaluation
    public func runSecurityAudit() async -> SecurityAuditReport {
        var items: [SecurityPostureItem] = []
        let totalPossibleScore = 100
        
        // 1. System Integrity Protection (SIP) - 30 Puan
        let sipRes = await commandRunner(.csrutil, ["status"])
        let isSIPEnabled = sipRes.isSuccess ? sipRes.stdout.localizedCaseInsensitiveContains("enabled") : nil
        if isSIPEnabled == true {
            items.append(SecurityPostureItem(
                id: "sip",
                title: L10n.string("System Integrity Protection (SIP)", table: .services),
                detail: L10n.string("Prevents unauthorized changes to system files and the kernel.", table: .services),
                isSecure: true,
                statusText: L10n.string("Active (Protected)", table: .services),
                recommendation: L10n.string("SIP protection is active. The system core is secure.", table: .services),
                severity: .secure
            ))
        } else if isSIPEnabled == false {
            items.append(SecurityPostureItem(
                id: "sip",
                title: L10n.string("System Integrity Protection (SIP)", table: .services),
                detail: L10n.string("SIP is disabled. Malware may tamper with root system files.", table: .services),
                isSecure: false,
                statusText: L10n.string("Disabled (Dangerous)", table: .services),
                recommendation: L10n.string("Enable it by starting your Mac in Recovery Mode and running 'csrutil enable'.", table: .services),
                severity: .critical
            ))
        } else {
            items.append(Self.unknownItem(id: "sip", title: L10n.string("System Integrity Protection (SIP)", table: .services)))
        }
        
        // 2. Gatekeeper (Uygulama İndirme & Kod İmza Doğrulama) - 25 Puan
        let spctlRes = await commandRunner(.spctl, ["--status"])
        let isGatekeeperEnabled: Bool? = spctlRes.isSuccess ? spctlRes.stdout.localizedCaseInsensitiveContains("assessments enabled") : nil
        if isGatekeeperEnabled == true {
            items.append(SecurityPostureItem(
                id: "gatekeeper",
                title: L10n.string("Apple Gatekeeper Security", table: .services),
                detail: L10n.string("Allows only trusted apps approved by Apple and signed with notarization to run.", table: .services),
                isSecure: true,
                statusText: L10n.string("Active (Verification On)", table: .services),
                recommendation: L10n.string("Unsigned and unverified binaries are blocked.", table: .services),
                severity: .secure
            ))
        } else if isGatekeeperEnabled == false {
            items.append(SecurityPostureItem(
                id: "gatekeeper",
                title: L10n.string("Apple Gatekeeper Security", table: .services),
                detail: L10n.string("Gatekeeper is off. Unsigned or malicious binaries may run without warning.", table: .services),
                isSecure: false,
                statusText: L10n.string("Disabled", table: .services),
                recommendation: L10n.string("Re-enable Gatekeeper by running 'sudo spctl --master-enable' in Terminal.", table: .services),
                severity: .critical
            ))
        } else {
            items.append(Self.unknownItem(id: "gatekeeper", title: L10n.string("Apple Gatekeeper Security", table: .services)))
        }
        
        // 3. macOS Güvenlik Duvarı (Firewall) - 25 Puan
        let firewallRes = await commandRunner(.socketfilterfw, ["--getglobalstate"])
        let firewallText = firewallRes.stdout.lowercased()
        let isFirewallEnabled: Bool? = firewallRes.isSuccess
            ? (firewallText.contains("firewall is enabled") ? true : firewallText.contains("firewall is disabled") ? false : nil)
            : nil
        if isFirewallEnabled == true {
            items.append(SecurityPostureItem(
                id: "firewall",
                title: L10n.string("macOS Application Firewall", table: .services),
                detail: L10n.string("Filters and blocks unauthorized incoming network connection requests.", table: .services),
                isSecure: true,
                statusText: L10n.string("Active (Filtering On)", table: .services),
                recommendation: L10n.string("The firewall is blocking unauthorized incoming port scans.", table: .services),
                severity: .secure
            ))
        } else if isFirewallEnabled == false {
            items.append(SecurityPostureItem(
                id: "firewall",
                title: L10n.string("macOS Application Firewall", table: .services),
                detail: L10n.string("The system firewall is off. This may pose a risk on public Wi-Fi networks.", table: .services),
                isSecure: false,
                statusText: L10n.string("Off", table: .services),
                recommendation: L10n.string("You should enable it in System Settings > Network > Firewall.", table: .services),
                severity: .warning
            ))
        } else {
            items.append(Self.unknownItem(id: "firewall", title: L10n.string("macOS Application Firewall", table: .services)))
        }
        
        // 4. Erişilebilirlik & Güvenlik İzinleri (Accessibility / TCC) - 20 Puan
        let isTrusted = accessibilityChecker()
        if isTrusted {
            items.append(SecurityPostureItem(
                id: "accessibility",
                title: L10n.string("System Utility Permissions", table: .services),
                detail: L10n.string("The app has permission for full system optimization and window management.", table: .services),
                isSecure: true,
                statusText: L10n.string("Approved", table: .services),
                recommendation: L10n.string("Required access permissions are configured successfully.", table: .services),
                severity: .secure
            ))
        } else {
            items.append(SecurityPostureItem(
                id: "accessibility",
                title: L10n.string("Accessibility Permissions", table: .services),
                detail: L10n.string("Running with standard user permissions (Sandbox / Non-Privileged).", table: .services),
                isSecure: true,
                statusText: L10n.string("Standard Permission", table: .services),
                recommendation: L10n.string("You can grant permission in System Settings for advanced window automation.", table: .services),
                severity: .secure
            ))
        }
        
        let finalScore = min(totalPossibleScore, Self.score(sip: isSIPEnabled, gatekeeper: isGatekeeperEnabled, firewall: isFirewallEnabled, accessibility: isTrusted))
        return SecurityAuditReport(
            score: finalScore,
            items: items,
            scannedDate: Date()
        )
    }

    static func score(sip: Bool?, gatekeeper: Bool?, firewall: Bool?, accessibility: Bool) -> Int {
        (sip == true ? 30 : 0) + (gatekeeper == true ? 25 : 0) + (firewall == true ? 25 : 0) + (accessibility ? 20 : 0)
    }

    private static func unknownItem(id: String, title: String) -> SecurityPostureItem {
        SecurityPostureItem(id: id, title: title, detail: L10n.string("Could not read the status of this setting.", table: .services), isSecure: false,
                            statusText: L10n.string("Unknown", table: .services), recommendation: L10n.string("Verify the status in macOS System Settings.", table: .services), severity: .warning)
    }
}
