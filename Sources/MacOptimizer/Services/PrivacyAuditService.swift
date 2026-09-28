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
        case 90...100: return "Mükemmel Güvenlik Kalkanı"
        case 70..<90:  return "İyi / Standart Güvenlik"
        case 50..<70:  return "Geliştirilmesi Gereken Ayarlar"
        default:       return "Kritik Güvenlik Riski"
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
                title: "System Integrity Protection (SIP)",
                detail: "Sistem dosyalarını ve çekirdek seviyesi izinsiz değişiklikleri engeller.",
                isSecure: true,
                statusText: "Aktif (Korumalı)",
                recommendation: "SIP koruması devrede. Sistemin temel bütünlüğü güvende.",
                severity: .secure
            ))
        } else if isSIPEnabled == false {
            items.append(SecurityPostureItem(
                id: "sip",
                title: "System Integrity Protection (SIP)",
                detail: "SIP devre dışı bırakılmış. Kötü amaçlı yazılımlar kök sistem dosyalarına müdahale edebilir.",
                isSecure: false,
                statusText: "Devre Dışı (Tehlikeli)",
                recommendation: "Mac'inizi Kurtarma Modunda (Recovery) başlatıp 'csrutil enable' çalıştırarak etkinleştirin.",
                severity: .critical
            ))
        } else {
            items.append(Self.unknownItem(id: "sip", title: "System Integrity Protection (SIP)"))
        }
        
        // 2. Gatekeeper (Uygulama İndirme & Kod İmza Doğrulama) - 25 Puan
        let spctlRes = await commandRunner(.spctl, ["--status"])
        let isGatekeeperEnabled: Bool? = spctlRes.isSuccess ? spctlRes.stdout.localizedCaseInsensitiveContains("assessments enabled") : nil
        if isGatekeeperEnabled == true {
            items.append(SecurityPostureItem(
                id: "gatekeeper",
                title: "Apple Gatekeeper Güvenliği",
                detail: "Yalnızca Apple onaylı ve Notarized imzalı güvenilir uygulamaların çalışmasına izin verir.",
                isSecure: true,
                statusText: "Aktif (Doğrulama Açık)",
                recommendation: "İmzasız ve doğrulanmamış ikili dosyalar engelleniyor.",
                severity: .secure
            ))
        } else if isGatekeeperEnabled == false {
            items.append(SecurityPostureItem(
                id: "gatekeeper",
                title: "Apple Gatekeeper Güvenliği",
                detail: "Gatekeeper kapalı. İmzasız veya kötü amaçlı ikili dosyalar uyarı vermeden çalışabilir.",
                isSecure: false,
                statusText: "Devre Dışı",
                recommendation: "Terminalde 'sudo spctl --master-enable' çalıştırarak Gatekeeper'ı tekrar açın.",
                severity: .critical
            ))
        } else {
            items.append(Self.unknownItem(id: "gatekeeper", title: "Apple Gatekeeper Güvenliği"))
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
                title: "macOS Uygulama Güvenlik Duvarı",
                detail: "Yetkisiz gelen ağ bağlantı isteklerini filtreler ve engeller.",
                isSecure: true,
                statusText: "Aktif (Filtreleme Devrede)",
                recommendation: "Güvenlik duvarı gelen yetkisiz port taramalarını engelliyor.",
                severity: .secure
            ))
        } else if isFirewallEnabled == false {
            items.append(SecurityPostureItem(
                id: "firewall",
                title: "macOS Uygulama Güvenlik Duvarı",
                detail: "Sistem Güvenlik Duvarı kapalı. Halka açık Wi-Fi ağlarında risk oluşturabilir.",
                isSecure: false,
                statusText: "Kapalı",
                recommendation: "Sistem Ayarları > Ağ > Güvenlik Duvarı bölümünden etkinleştirmeniz önerilir.",
                severity: .warning
            ))
        } else {
            items.append(Self.unknownItem(id: "firewall", title: "macOS Uygulama Güvenlik Duvarı"))
        }
        
        // 4. Erişilebilirlik & Güvenlik İzinleri (Accessibility / TCC) - 20 Puan
        let isTrusted = accessibilityChecker()
        if isTrusted {
            items.append(SecurityPostureItem(
                id: "accessibility",
                title: "Sistem Yardımcı Program İzinleri",
                detail: "Uygulama tam sistem optimizasyonu ve pencere yönetimi yetkisine sahip.",
                isSecure: true,
                statusText: "Onaylandı",
                recommendation: "Gerekli erişim izinleri başarıyla yapılandırılmış.",
                severity: .secure
            ))
        } else {
            items.append(SecurityPostureItem(
                id: "accessibility",
                title: "Erişilebilirlik İzinleri",
                detail: "Standart kullanıcı izinlerinde çalışıyor (Sandbox / Non-Privileged).",
                isSecure: true,
                statusText: "Standart İzin",
                recommendation: "İleri düzey pencere otomasyonu için Sistem Ayarları'ndan izin verebilirsiniz.",
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
        SecurityPostureItem(id: id, title: title, detail: "Bu ayarın durumu okunamadı.", isSecure: false,
                            statusText: "Bilinmiyor", recommendation: "Durumu macOS Sistem Ayarları'ndan doğrulayın.", severity: .warning)
    }
}
