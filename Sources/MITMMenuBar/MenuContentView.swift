import SwiftUI
import AppKit

/// The entire app lives in this popup. Keep the header and footer visible while
/// settings and response rules scroll, so a large rule list never leaves the screen.
struct MenuContentView: View {
    @ObservedObject var proxy: ProxyManager
    @ObservedObject var mitmweb: MitmwebManager
    @ObservedObject var overrides: OverridesStore

    @State private var expandedRuleID: UUID?
    @State private var portDraft = ""
    @State private var invalidPort = false

    private var everythingOn: Bool { proxy.isEnabled && mitmweb.isRunning }
    private var enabledRuleCount: Int { overrides.rules.filter(\.enabled).count }
    private var contentHeight: CGFloat {
        let available = (NSScreen.main?.visibleFrame.height ?? 800) - 180
        let preferred = overrides.rules.isEmpty ? CGFloat(440)
            : CGFloat(300 + overrides.rules.count * 70 + (expandedRuleID == nil ? 0 : 370))
        return min(max(280, min(560, available)), preferred)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(16)

            Divider()

            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        connectionSection
                        corsSection
                        overridesSection
                    }
                    .padding(16)
                }
                .frame(height: contentHeight)
                .onChange(of: expandedRuleID) { id in
                    if let id {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            scroll.scrollTo(id, anchor: .top)
                        }
                    }
                }
            }

            Divider()
            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 420)
        .font(.system(size: 13))
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            portDraft = String(mitmweb.webPort)
            proxy.checkStatus()
            mitmweb.checkStatus()
        }
        .onChange(of: mitmweb.webPort) { portDraft = String($0) }
        .onChange(of: overrides.rules) { _ in overrides.save() }
        .onChange(of: overrides.corsBypass) { _ in overrides.save() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
               let icon = NSImage(contentsOf: iconURL) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 38, height: 38)
            } else {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 38, height: 38)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("MITM Menu Bar")
                    .font(.system(size: 16, weight: .semibold))
                HStack(spacing: 5) {
                    Circle().fill(statusColor).frame(width: 6, height: 6)
                    Text(statusText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            powerButton
        }
    }

    private var powerButton: some View {
        Button(action: toggleEverything) {
            Label(everythingOn ? "Stop all" : "Start all",
                  systemImage: everythingOn ? "stop.fill" : "play.fill")
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .help(everythingOn ? "Disable the proxy and stop the web console" : "Start the web console and enable the proxy")
    }

    private var statusText: String {
        if everythingOn { return "Proxy and console running" }
        if proxy.isEnabled { return "Console offline · traffic interrupted" }
        if mitmweb.isRunning { return "Console running · proxy off" }
        return "Ready to start"
    }

    private var statusColor: Color {
        if everythingOn { return .green }
        if proxy.isEnabled { return .red }
        if mitmweb.isRunning { return .orange }
        return .secondary
    }

    private var connectionSection: some View {
        VStack(spacing: 0) {
            SettingsToggle(title: "System proxy", subtitle: "Route HTTP and HTTPS traffic",
                           symbol: "network", isOn: Binding(
                get: { proxy.isEnabled },
                set: { on in
                    if on {
                        if !mitmweb.isRunning { mitmweb.start() }
                        proxy.enable()
                    } else {
                        proxy.disable()
                    }
                }
            ))
            .padding(12)

            Divider().padding(.leading, 42)

            SettingsToggle(title: "Web console", subtitle: "Inspect requests at localhost:\(mitmweb.webPort)",
                           symbol: "terminal", isOn: Binding(
                get: { mitmweb.isRunning },
                set: { on in
                    if on {
                        mitmweb.start()
                    } else {
                        mitmweb.stop()
                        if proxy.isEnabled { proxy.disable() }
                    }
                }
            ))
            .padding(12)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Console port").foregroundStyle(.secondary)
                    TextField("8081", text: $portDraft)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 64)
                        .onSubmit(commitPort)
                        .accessibilityLabel("Console port")
                        .help("Press Return to apply. Changing the port restarts the console.")
                    Spacer()
                    Button {
                        if let url = URL(string: "http://127.0.0.1:\(mitmweb.webPort)") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("Open console", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.primary)
                    .disabled(!mitmweb.isRunning)
                }
                if invalidPort {
                    Label("Enter a port from 1 to 65535.", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(12)
        }
        .panelStyle()
    }

    private var corsSection: some View {
        SettingsToggle(title: "Bypass CORS", subtitle: "Allow cross-origin requests during development",
                       symbol: "globe", isOn: $overrides.corsBypass)
            .padding(.horizontal, 12)
            .help("Add CORS headers and answer browser preflight requests.")
    }

    private var overridesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Response Overrides").font(.system(size: 13, weight: .semibold))
                    Text(overrides.rules.isEmpty ? "Mock a response or add a delay" : "\(enabledRuleCount) of \(overrides.rules.count) rules enabled")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    let rule = overrides.addRule()
                    expandedRuleID = rule.id
                } label: {
                    Label("Add rule", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if overrides.rules.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text("Your endpoints, your responses")
                        .font(.system(size: 13, weight: .medium))
                    Text("Add a URL or path to mock its response\nor simulate a slower connection.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .panelStyle()
            } else {
                VStack(spacing: 8) {
                    ForEach($overrides.rules) { $rule in
                        RuleRow(rule: $rule, isExpanded: Binding(
                            get: { expandedRuleID == rule.id },
                            set: { expandedRuleID = $0 ? rule.id : nil }
                        ), onCommit: { overrides.save() }, onDelete: {
                            if expandedRuleID == rule.id { expandedRuleID = nil }
                            overrides.delete(id: rule.id)
                        })
                        .id(rule.id)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
    }

    private func toggleEverything() {
        if everythingOn {
            proxy.disable()
            mitmweb.stop()
        } else {
            mitmweb.start()
            proxy.enable()
        }
    }

    private func commitPort() {
        guard let port = Int(portDraft.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...65535).contains(port) else {
            invalidPort = true
            return
        }
        invalidPort = false
        portDraft = String(port)
        if port != mitmweb.webPort {
            mitmweb.webPort = port
            mitmweb.applyPortChange()
        }
    }
}

private struct SettingsToggle: View {
    let title: String
    let subtitle: String
    let symbol: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 13, weight: .medium))
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .accessibilityLabel(title)
        }
    }
}

private struct RuleRow: View {
    @Binding var rule: OverrideRule
    @Binding var isExpanded: Bool
    let onCommit: () -> Void
    let onDelete: () -> Void

    @State private var editorHeight: CGFloat = 140
    @State private var dragStartHeight: CGFloat?
    @FocusState private var endpointFocused: Bool

    private static let methods = ["ANY", "GET", "POST", "PUT", "PATCH", "DELETE"]

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Circle().fill(rule.enabled ? Color.green : Color.secondary)
                        .frame(width: 6, height: 6)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(endpointTitle)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        HStack(spacing: 5) {
                            RuleBadge(text: rule.method ?? "ANY")
                            RuleBadge(text: rule.overrideResponse ? String(rule.statusCode) : "Pass through")
                            if rule.delaySeconds > 0 {
                                RuleBadge(text: "\(rule.delaySeconds.formatted())s", symbol: "clock", highlighted: true)
                            }
                            if let host = endpointHost {
                                Text(host).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(rule.endpoint.isEmpty ? "Configure this endpoint rule" : rule.endpoint)
            .accessibilityLabel("\(rule.endpoint.isEmpty ? "New rule" : rule.endpoint), \(rule.enabled ? "enabled" : "disabled")")
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

            if isExpanded {
                Divider()
                editor.padding(12)
            }
        }
        .panelStyle()
        .onChange(of: isExpanded) { expanded in
            if expanded && rule.endpoint.isEmpty { endpointFocused = true }
        }
        .onAppear {
            if isExpanded && rule.endpoint.isEmpty { endpointFocused = true }
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rule enabled").font(.system(size: 12, weight: .medium))
                Spacer()
                Toggle("Rule enabled", isOn: $rule.enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 5) {
                fieldLabel("Endpoint")
                TextField("URL or path, e.g. /api/users", text: $rule.endpoint)
                    .textFieldStyle(.roundedBorder)
                    .focused($endpointFocused)
                    .onSubmit(onCommit)
                    .accessibilityLabel("Endpoint URL or path")
                Text("Matches any URL containing this text.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    fieldLabel("HTTP method")
                    Picker("HTTP method", selection: Binding(
                        get: { rule.method ?? "ANY" },
                        set: { rule.method = $0 == "ANY" ? nil : $0 }
                    )) {
                        ForEach(Self.methods, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 110)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 5) {
                    fieldLabel("Response delay")
                    HStack(spacing: 5) {
                        TextField("0", value: Binding(
                            get: { rule.delaySeconds },
                            set: { rule.delaySeconds = $0.isFinite ? max(0, $0) : 0 }
                        ), format: .number.grouping(.never))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                            .onSubmit(onCommit)
                            .accessibilityLabel("Response delay in seconds")
                        Text("seconds").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
            }
            .help("Delay adds extra time before returning the response. 0 means no delay; decimals are allowed.")

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Override response").font(.system(size: 12, weight: .medium))
                    Text(rule.overrideResponse ? "Return your custom status and JSON" : "Keep the real response and only apply the delay")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Toggle("Override response", isOn: $rule.overrideResponse)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            if rule.overrideResponse {
                responseEditor
            }

            HStack {
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Label("Delete rule", systemImage: "trash")
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11))
                .foregroundStyle(.red)
            }
        }
    }

    private var responseEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                fieldLabel("Response JSON")
                if !isValidJSON(rule.responseBody) {
                    Label("Invalid JSON", systemImage: "exclamationmark.triangle")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }
                Spacer()
                Text("Status").font(.system(size: 11)).foregroundStyle(.secondary)
                TextField("200", value: $rule.statusCode, format: .number.grouping(.never))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 52)
                    .onSubmit(onCommit)
                    .accessibilityLabel("Response status code")
            }
            TextEditor(text: $rule.responseBody)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(5)
                .frame(height: editorHeight)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor)))
                .accessibilityLabel("Response JSON body")
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(5)
                        .contentShape(Rectangle())
                        .help("Drag to resize the response editor")
                        .onHover { inside in
                            if inside { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let base = dragStartHeight ?? editorHeight
                                    if dragStartHeight == nil { dragStartHeight = base }
                                    editorHeight = min(360, max(80, base + value.translation.height))
                                }
                                .onEnded { _ in dragStartHeight = nil }
                        )
                }
        }
    }

    private var endpointComponents: URLComponents? {
        let components = URLComponents(string: rule.endpoint.trimmingCharacters(in: .whitespacesAndNewlines))
        return components?.host == nil ? nil : components
    }

    private var endpointTitle: String {
        if rule.endpoint.isEmpty { return "New endpoint" }
        guard let components = endpointComponents else { return rule.endpoint }
        let path = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
        return path + (components.percentEncodedQuery.map { "?" + $0 } ?? "")
    }

    private var endpointHost: String? {
        guard let components = endpointComponents, let host = components.host else { return nil }
        return host + (components.port.map { ":\($0)" } ?? "")
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
    }
}

private struct RuleBadge: View {
    let text: String
    var symbol: String? = nil
    var highlighted = false
    private var color: Color {
        highlighted ? .primary : .secondary
    }

    var body: some View {
        HStack(spacing: 3) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(color)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(color.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 4))
        .fixedSize()
    }
}

private extension View {
    func panelStyle() -> some View {
        background(Color(nsColor: .controlBackgroundColor).opacity(0.6),
                   in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor).opacity(0.6)))
    }
}

private func isValidJSON(_ string: String) -> Bool {
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return false }
    return (try? JSONSerialization.jsonObject(with: data)) != nil
}
