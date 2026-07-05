import SwiftUI
import AppKit

/// The entire UI lives in the menu bar popup: proxy/console toggles and the
/// inline response-override editor.
struct MenuContentView: View {
    @ObservedObject var proxy: ProxyManager
    @ObservedObject var mitmweb: MitmwebManager
    @ObservedObject var overrides: OverridesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let everythingOn = proxy.isEnabled && mitmweb.isRunning
            Button(everythingOn ? "Turn Everything Off" : "Turn Everything On") {
                if everythingOn {
                    proxy.disable()
                    mitmweb.stop()
                } else {
                    proxy.enable()
                    mitmweb.start()
                }
            }
            .buttonStyle(.borderedProminent)

            Divider()

            // The proxy points system traffic at 127.0.0.1:8080, so it only
            // works while mitmweb is listening there. Enabling the proxy starts
            // the console, and stopping the console disables the proxy — this
            // makes the "proxy on, no server" (no-internet) state unreachable.
            Toggle("Proxy Enabled", isOn: Binding(
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

            Toggle("Web Console", isOn: Binding(
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

            HStack {
                Text("Console port")
                TextField("8081", value: $mitmweb.webPort, format: .number.grouping(.never))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                    .onSubmit { mitmweb.applyPortChange() }
                    .help("Web UI port. Changing it while running restarts the console.")
            }

            Button("Open mitmproxy Web UI") {
                if let url = URL(string: "http://127.0.0.1:\(mitmweb.webPort)") {
                    NSWorkspace.shared.open(url)
                }
            }
            .disabled(!mitmweb.isRunning)

            Toggle("Bypass CORS (dev)", isOn: $overrides.corsBypass)
                .help("Inject Access-Control-Allow-* headers into responses and answer preflight requests, so a browser dev client can call APIs that don't allow its origin.")

            Divider()

            overridesSection

            Divider()

            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .padding(12)
        .frame(width: 360)
        .onAppear {
            // Bring the app forward so the popup becomes key and its text
            // fields accept keyboard input (paste), and refresh status.
            NSApp.activate(ignoringOtherApps: true)
            proxy.checkStatus()
            mitmweb.checkStatus()
        }
        // Persist on any edit so the running mitmproxy addon picks it up live.
        .onChange(of: overrides.rules) { _ in overrides.save() }
        .onChange(of: overrides.corsBypass) { _ in overrides.save() }
    }

    private var overridesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Response Overrides").font(.headline)
                Spacer()
                Button {
                    _ = overrides.addRule()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Add a rule")
            }

            if overrides.rules.isEmpty {
                Text("No rules — click + to mock an endpoint.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 4) {
                    ForEach($overrides.rules) { $rule in
                        RuleRow(rule: $rule,
                            onCommit: { overrides.save() },
                            onDelete: { overrides.delete(id: rule.id) })
                    }
                }
            }
        }
    }
}

/// One override rule, collapsed to a summary row that expands to an editor.
private struct RuleRow: View {
    @Binding var rule: OverrideRule
    let onCommit: () -> Void
    let onDelete: () -> Void

    @State private var expanded = false
    @State private var editorHeight: CGFloat = 120
    @State private var dragStartHeight: CGFloat?

    private static let methods = ["ANY", "GET", "POST", "PUT", "PATCH", "DELETE"]

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Enabled", isOn: $rule.enabled)

                TextField("/api/v1/users", text: $rule.endpoint)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(onCommit)

                HStack {
                    Picker("", selection: Binding(
                        get: { rule.method ?? "ANY" },
                        set: { rule.method = ($0 == "ANY") ? nil : $0 }
                    )) {
                        ForEach(Self.methods, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 110)

                    Spacer()

                    Text("Status")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("200", value: $rule.statusCode, format: .number.grouping(.never))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 56)
                        .onSubmit(onCommit)
                }

                HStack {
                    Text("Response JSON")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !isValidJSON(rule.responseBody) {
                        Label("Invalid JSON", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                TextEditor(text: $rule.responseBody)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: editorHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(.secondary.opacity(0.3))
                    )
                    // Drag the corner grip to resize the editor to any height.
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(90))
                            .padding(3)
                            .contentShape(Rectangle())
                            .onHover { inside in
                                if inside { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let base = dragStartHeight ?? editorHeight
                                        if dragStartHeight == nil { dragStartHeight = base }
                                        editorHeight = max(60, base + value.translation.height)
                                    }
                                    .onEnded { _ in dragStartHeight = nil }
                            )
                    }

                Button(role: .destructive, action: onDelete) {
                    Label("Delete rule", systemImage: "trash")
                }
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 4)
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(rule.enabled ? Color.green : Color.secondary)
                    .frame(width: 7, height: 7)
                Text(rule.endpoint.isEmpty ? "(new rule)" : rule.endpoint)
                    .lineLimit(1)
                Spacer()
                Text("\(rule.method ?? "ANY") · \(rule.statusCode)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private func isValidJSON(_ string: String) -> Bool {
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return false }
    return (try? JSONSerialization.jsonObject(with: data)) != nil
}
