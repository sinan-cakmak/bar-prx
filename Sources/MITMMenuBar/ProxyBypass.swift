import Foundation

/// HTTPS destinations that must pass through mitmproxy without TLS inspection.
/// Apple explicitly rejects inspected connections for iCloud, and WhatsApp's
/// clients protect their media connections in the same way.
enum ProxyBypass {
    static let domains = [
        // Apple Account, iCloud, CloudKit, and Apple-hosted content.
        "apple.com",
        "apple-cloudkit.com",
        "apple-livephotoskit.com",
        "apzones.com",
        "cdn-apple.com",
        "icloud.com",
        "icloud.com.cn",
        "icloud-content.com",
        "mzstatic.com",
        "apple-dns.net",

        // WhatsApp app, media, and attachment delivery.
        "whatsapp.com",
        "whatsapp.net",
        "fbcdn.net",
        "fbsbx.com",
    ]

    /// mitmproxy matches `ignore_hosts` against `host:port` CONNECT targets.
    /// Anchor both ends so deceptive suffixes such as apple.com.example.net
    /// remain inspectable.
    static let httpsHostPattern: String = {
        let alternatives = domains
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
        return "^(?:[^.:]+\\.)*(?:\(alternatives)):443$"
    }()
}
