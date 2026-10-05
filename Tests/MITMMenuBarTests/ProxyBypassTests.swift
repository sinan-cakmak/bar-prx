import Foundation
import XCTest
@testable import MITMMenuBar

final class ProxyBypassTests: XCTestCase {
    func testBypassesAppleAndICloudServiceHosts() throws {
        let hosts = [
            "apple.com:443",
            "api.apple.com:443",
            "p37-drivews.icloud-content.com:443",
            "api.apple-cloudkit.com:443",
            "gateway.icloud.com:443",
            "cdn.mzstatic.com:443",
            "resolver.apple-dns.net:443",
        ]

        for host in hosts {
            XCTAssertTrue(try matches(host), "Expected bypass for \(host)")
        }
    }

    func testBypassesWhatsAppMediaHosts() throws {
        let hosts = [
            "web.whatsapp.com:443",
            "mmg.whatsapp.net:443",
            "media.fna.whatsapp.net:443",
            "scontent.fbom26-1.fna.fbcdn.net:443",
            "lookaside.fbsbx.com:443",
        ]

        for host in hosts {
            XCTAssertTrue(try matches(host), "Expected bypass for \(host)")
        }
    }

    func testDoesNotBypassUnrelatedHostsOrPorts() throws {
        let hosts = [
            "example.com:443",
            "notapple.com:443",
            "apple.com.example.net:443",
            "whatsapp.net.example.org:443",
            "mmg.whatsapp.net:80",
        ]

        for host in hosts {
            XCTAssertFalse(try matches(host), "Unexpected bypass for \(host)")
        }
    }

    private func matches(_ host: String) throws -> Bool {
        let arguments = MitmwebManager().mitmwebArguments
        let optionIndex = try XCTUnwrap(arguments.firstIndex(of: "--ignore-hosts"))
        let pattern = try XCTUnwrap(
            arguments.indices.contains(optionIndex + 1) ? arguments[optionIndex + 1] : nil
        )
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(host.startIndex..<host.endIndex, in: host)
        return regex.firstMatch(in: host, range: range)?.range == range
    }
}
