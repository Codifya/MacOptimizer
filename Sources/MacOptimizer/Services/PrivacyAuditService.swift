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
    
    public init() {}
    
    /// Performs a full macOS security & privacy posture evaluation
    public func runSecurityAudit() async -> SecurityAuditReport {
        var items: [SecurityPostureItem] = []
        var scoreAcc = 0
        let totalPossibleScore = 100
        
        // 1. System Integrity Protection (SIP) - 30 Puan
        let sipRes = await SandboxedCommandRunner.run(executable: .csrutil, arguments: ["status"])
        let isSIPEnabled = sipRes.stdout.localizedCaseInsensitiveContains("enabled")
        if isSIPEnabled {
            scoreAcc += 30
            items.append(SecurityPostureItem(
                id: "sip",
                title: "System Integrity Protection (SIP)",
                detail: "Sistem dosyalarını ve çekirdek seviyesi izinsiz değişiklikleri engeller.",
                isSecure: true,
                statusText: "Aktif (Korumalı)",
                recommendation: "SIP koruması devrede. Sistemin temel bütünlüğü güvende.",
                severity: .secure
            ))
        } else {
            items.append(SecurityPostureItem(
                id: "sip",
                title: "System Integrity Protection (SIP)",
                detail: "SIP devre dışı bırakılmış. Kötü amaçlı yazılımlar kök sistem dosyalarına müdahale edebilir.",
                isSecure: false,
                statusText: "Devre Dışı (Tehlikeli)",
                recommendation: "Mac'inizi Kurtarma Modunda (Recovery) başlatıp 'csrutil enable' çalıştırarak etkinleştirin.",
                severity: .critical
            ))
        }
        
        // 2. Gatekeeper (Uygulama İndirme & Kod İmza Doğrulama) - 25 Puan
        let spctlRes = await SandboxedCommandRunner.run(executable: .spctl, arguments: ["--status"])
        let isGatekeeperEnabled = spctlRes.stdout.localizedCaseInsensitiveContains("assessments enabled") || spctlRes.exitCode == 0
        if isGatekeeperEnabled {
            scoreAcc += 25
            items.append(SecurityPostureItem(
                id: "gatekeeper",
                title: "Apple Gatekeeper Güvenliği",
                detail: "Yalnızca Apple onaylı ve Notarized imzalı güvenilir uygulamaların çalışmasına izin verir.",
                isSecure: true,
                statusText: "Aktif (Doğrulama Açık)",
                recommendation: "İmzasız ve doğrulanmamış ikili dosyalar engelleniyor.",
                severity: .secure
            ))
        } else {
            items.append(SecurityPostureItem(
                id: "gatekeeper",
                title: "Apple Gatekeeper Güvenliği",
                detail: "Gatekeeper kapalı. İmzasız veya kötü amaçlı ikili dosyalar uyarı vermeden çalışabilir.",
                isSecure: false,
                statusText: "Devre Dışı",
                recommendation: "Terminalde 'sudo spctl --master-enable' çalıştırarak Gatekeeper'ı tekrar açın.",
                severity: .critical
            ))
        }
        
        // 3. macOS Güvenlik Duvarı (Firewall) - 25 Puan
        let alfRes = await SandboxedCommandRunner.run(
            executable: .defaults,
            arguments: ["read", "/Library/Preferences/com.apple.alf", "globalstate"]
        )
        let alfVal = Int(alfRes.stdout.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let isFirewallEnabled = alfVal > 0
        if isFirewallEnabled {
            scoreAcc += 25
            items.append(SecurityPostureItem(
                id: "firewall",
                title: "macOS Uygulama Güvenlik Duvarı",
                detail: "Yetkisiz gelen ağ bağlantı isteklerini filtreler ve engeller.",
                isSecure: true,
                statusText: "Aktif (Filtreleme Devrede)",
                recommendation: "Güvenlik duvarı gelen yetkisiz port taramalarını engelliyor.",
                severity: .secure
            ))
        } else {
            scoreAcc += 10 // Kısmi puan
            items.append(SecurityPostureItem(
                id: "firewall",
                title: "macOS Uygulama Güvenlik Duvarı",
                detail: "Sistem Güvenlik Duvarı kapalı. Halka açık Wi-Fi ağlarında risk oluşturabilir.",
                isSecure: false,
                statusText: "Kapalı",
                recommendation: "Sistem Ayarları > Ağ > Güvenlik Duvarı bölümünden etkinleştirmeniz önerilir.",
                severity: .warning
            ))
        }
        
        // 4. Erişilebilirlik & Güvenlik İzinleri (Accessibility / TCC) - 20 Puan
        let isTrusted = AXIsProcessTrusted()
        if isTrusted {
            scoreAcc += 20
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
            scoreAcc += 20 // Kullanıcı vermemiş olsa bile bu bir güvenlik riski değil, kısıtlı mod
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
        
        let finalScore = min(totalPossibleScore, scoreAcc)
        return SecurityAuditReport(
            score: finalScore,
            items: items,
            scannedDate: Date()
        )
    }
}
