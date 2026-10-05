import Foundation
import XCTest
@testable import MITMMenuBar

final class OverrideRuleTests: XCTestCase {
    func testLegacyRuleKeepsMockWithNoDelay() throws {
        let json = """
        {"id":"A7828C85-38B1-4E6A-834E-C88A567207D3","endpoint":"/users",
         "statusCode":201,"responseBody":"{}","enabled":false}
        """
        let rule = try JSONDecoder().decode(OverrideRule.self, from: Data(json.utf8))
        XCTAssertTrue(rule.overrideResponse)
        XCTAssertEqual(rule.delaySeconds, 0)
        XCTAssertEqual(rule.statusCode, 201)
        XCTAssertFalse(rule.enabled)
        XCTAssertNil(rule.method)
    }

    func testDelayOnlyRuleRoundTrips() throws {
        let rule = OverrideRule(endpoint: "/users", method: "GET",
                                overrideResponse: false, delaySeconds: 5.5)
        let data = try JSONEncoder().encode(rule)
        XCTAssertEqual(try JSONDecoder().decode(OverrideRule.self, from: data), rule)
    }

    func testInvalidDelaysBecomeZero() {
        for delay in [-1.0, .infinity, -.infinity, .nan] {
            XCTAssertEqual(OverrideRule(delaySeconds: delay).delaySeconds, 0)
        }
    }

    func testEmbeddedAddonBehavior() throws {
        let python = URL(fileURLWithPath: "/usr/bin/python3")
        guard FileManager.default.isExecutableFile(atPath: python.path) else {
            throw XCTSkip("Python 3 is required to exercise the embedded addon")
        }
        let harness = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Addon/test_response_override.py")
        let process = Process()
        process.executableURL = python
        process.arguments = [harness.path]
        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = output
        try process.run()
        input.fileHandleForWriting.write(Data(OverridesStore.addonScript.utf8))
        try input.fileHandleForWriting.close()
        let result = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, String(decoding: result, as: UTF8.self))
    }
}
