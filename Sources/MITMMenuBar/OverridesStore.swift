import Foundation
import Combine

// MARK: - Shared paths

enum OverridePaths {
    /// ~/.mitmmenubar
    static let dir: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".mitmmenubar", isDirectory: true)

    /// Rules file read live by the mitmproxy addon.
    static let rules: URL = dir.appendingPathComponent("overrides.json")

    /// The mitmproxy addon script, written out at launch.
    static let script: URL = dir.appendingPathComponent("response_override.py")
}

// MARK: - Model

/// A single response-override rule. Property names are the exact keys the
/// Python addon reads from overrides.json — keep them in sync.
struct OverrideRule: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    /// Substring matched against the full request URL (e.g. "/api/users").
    var endpoint: String
    /// Optional HTTP method filter ("GET", "POST", …); nil means any method.
    var method: String?
    /// Status code returned to the client.
    var statusCode: Int
    /// Raw response body returned to the client (expected to be JSON).
    var responseBody: String
    /// When false, preserve the upstream response and only apply the delay.
    var overrideResponse: Bool
    /// Extra time to hold a response before returning it to the client.
    var delaySeconds: Double
    var enabled: Bool

    init(id: UUID = UUID(),
         endpoint: String = "",
         method: String? = nil,
         statusCode: Int = 200,
         responseBody: String = "{\n  \n}",
         overrideResponse: Bool = true,
         delaySeconds: Double = 0,
         enabled: Bool = true) {
        self.id = id
        self.endpoint = endpoint
        self.method = method
        self.statusCode = statusCode
        self.responseBody = responseBody
        self.overrideResponse = overrideResponse
        self.delaySeconds = delaySeconds.isFinite ? max(0, delaySeconds) : 0
        self.enabled = enabled
    }

    private enum CodingKeys: String, CodingKey {
        case id, endpoint, method, statusCode, responseBody, overrideResponse, delaySeconds, enabled
    }

    // Older saved rules have no delay or override toggle; keep their behavior.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try values.decode(UUID.self, forKey: .id),
            endpoint: try values.decode(String.self, forKey: .endpoint),
            method: try values.decodeIfPresent(String.self, forKey: .method),
            statusCode: try values.decode(Int.self, forKey: .statusCode),
            responseBody: try values.decode(String.self, forKey: .responseBody),
            overrideResponse: try values.decodeIfPresent(Bool.self, forKey: .overrideResponse) ?? true,
            delaySeconds: try values.decodeIfPresent(Double.self, forKey: .delaySeconds) ?? 0,
            enabled: try values.decode(Bool.self, forKey: .enabled)
        )
    }
}

private struct RulesFile: Codable {
    var rules: [OverrideRule]
    var corsBypass: Bool?
}

// MARK: - Store

/// Owns the override rules, persists them to disk, and writes the addon script.
/// The mitmproxy addon re-reads overrides.json on every request (mtime-cached),
/// so edits here take effect live without restarting mitmweb.
final class OverridesStore: ObservableObject {
    @Published var rules: [OverrideRule] = []
    /// Inject CORS headers into all proxied responses (and answer preflights),
    /// so a browser-based dev client can call APIs that don't allow its origin.
    @Published var corsBypass: Bool = false

    init() {
        bootstrap()
        load()
    }

    /// Ensure the config directory, addon script, and rules file exist.
    private func bootstrap() {
        try? FileManager.default.createDirectory(
            at: OverridePaths.dir,
            withIntermediateDirectories: true
        )

        // Always (re)write the addon so it stays in sync with this build.
        try? Self.addonScript.write(to: OverridePaths.script, atomically: true, encoding: .utf8)

        if !FileManager.default.fileExists(atPath: OverridePaths.rules.path) {
            save()
        }
    }

    func load() {
        guard let data = try? Data(contentsOf: OverridePaths.rules),
              let decoded = try? JSONDecoder().decode(RulesFile.self, from: data) else {
            return
        }
        rules = decoded.rules
        corsBypass = decoded.corsBypass ?? false
    }

    /// Persist rules to disk. The addon picks up the change on its next request.
    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let file = RulesFile(rules: rules, corsBypass: corsBypass)
        guard let data = try? encoder.encode(file) else { return }
        try? data.write(to: OverridePaths.rules, options: .atomic)
    }

    // MARK: - Mutations

    func addRule() -> OverrideRule {
        let rule = OverrideRule()
        rules.append(rule)
        save()
        return rule
    }

    func delete(id: UUID) {
        rules.removeAll { $0.id == id }
        save()
    }
}

// MARK: - Embedded mitmproxy addon

extension OverridesStore {
    /// Python addon loaded via `mitmweb -s`. Short-circuits matching requests in
    /// the `request` hook when overriding, or delays real upstream responses.
    /// Also answers CORS preflights and supports a global CORS bypass.
    /// Reloads config whenever overrides.json's modification time changes.
    static let addonScript = """
    # Auto-generated by MITMMenuBar. Do not edit by hand — it is overwritten on launch.
    import asyncio
    import json
    import math
    import os

    from mitmproxy import http

    OVERRIDES_PATH = os.path.expanduser("~/.mitmmenubar/overrides.json")

    _cache = {"mtime": None, "data": {"rules": [], "corsBypass": False}}
    _DELAY_KEY = "mitmmenubar_delay_seconds"


    def _load():
        try:
            mtime = os.path.getmtime(OVERRIDES_PATH)
        except OSError:
            _cache["mtime"] = None
            _cache["data"] = {"rules": [], "corsBypass": False}
            return _cache["data"]

        if mtime != _cache["mtime"]:
            try:
                with open(OVERRIDES_PATH, "r", encoding="utf-8") as f:
                    loaded = json.load(f)
                _cache["data"] = {
                    "rules": loaded.get("rules", []),
                    "corsBypass": bool(loaded.get("corsBypass", False)),
                }
                _cache["mtime"] = mtime
            except (OSError, ValueError):
                _cache["data"] = {"rules": [], "corsBypass": False}
        return _cache["data"]


    def _cors_headers(flow):
        # Reflect the caller's Origin so credentialed requests are allowed
        # (the wildcard "*" is rejected by browsers when credentials are sent).
        origin = flow.request.headers.get("Origin", "*")
        req_headers = flow.request.headers.get("Access-Control-Request-Headers", "*")
        headers = {
            "Access-Control-Allow-Origin": origin,
            "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
            "Access-Control-Allow-Headers": req_headers,
            "Access-Control-Max-Age": "86400",
        }
        if origin != "*":
            headers["Access-Control-Allow-Credentials"] = "true"
        return headers


    def _matches(rule, flow):
        if not rule.get("enabled", True):
            return False
        endpoint = (rule.get("endpoint") or "").strip()
        if not endpoint or endpoint not in flow.request.pretty_url:
            return False
        method = rule.get("method")
        # A preflight is always OPTIONS; don't let a method filter hide it.
        if method and flow.request.method != "OPTIONS" \\
                and method.upper() != flow.request.method.upper():
            return False
        return True


    def request(flow: http.HTTPFlow) -> None:
        # Capture this request's delay so live edits cannot change it mid-flight.
        flow.metadata.pop(_DELAY_KEY, None)
        data = _load()
        rules = data["rules"]
        cors = data["corsBypass"]

        # Answer CORS preflight requests so the browser proceeds to the real call.
        if flow.request.method == "OPTIONS":
            if cors or any(_matches(r, flow) and r.get("overrideResponse", True) for r in rules):
                flow.response = http.Response.make(204, b"", _cors_headers(flow))
            return

        for rule in rules:
            if not _matches(rule, flow):
                continue

            try:
                delay = float(rule.get("delaySeconds", 0))
            except (TypeError, ValueError, OverflowError):
                delay = 0
            if math.isfinite(delay) and delay > 0:
                flow.metadata[_DELAY_KEY] = delay

            # The first matching rule wins, including delay-only rules.
            if not rule.get("overrideResponse", True):
                return

            try:
                status = int(rule.get("statusCode", 200))
            except (TypeError, ValueError):
                status = 200

            body = rule.get("responseBody") or ""
            headers = {"Content-Type": "application/json"}
            # Always CORS-enable mocks so they work from a browser too.
            headers.update(_cors_headers(flow))
            flow.response = http.Response.make(status, body.encode("utf-8"), headers)
            return


    async def _delay_response(flow):
        delay = flow.metadata.pop(_DELAY_KEY, 0)
        if delay > 0:
            # Yield to the event loop so unrelated requests are not held up.
            await asyncio.sleep(delay)


    async def responseheaders(flow: http.HTTPFlow) -> None:
        # Hold headers before anything reaches the client, even with streaming on.
        await _delay_response(flow)


    async def response(flow: http.HTTPFlow) -> None:
        # Global CORS bypass: add headers to real (passed-through) responses.
        if _load()["corsBypass"]:
            for key, value in _cors_headers(flow).items():
                flow.response.headers[key] = value

        # Also covers synthetic responses that do not emit responseheaders.
        # Popping the delay ensures that it is only applied once per flow.
        await _delay_response(flow)
    """
}
