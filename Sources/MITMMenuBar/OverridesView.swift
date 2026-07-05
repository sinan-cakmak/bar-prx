import SwiftUI

/// Manage response-override rules. Rules are matched against the request URL by
/// substring; a match short-circuits the request and returns the custom JSON.
struct OverridesView: View {
    @ObservedObject var store: OverridesStore
    @State private var selection: UUID?

    private static let methods = ["ANY", "GET", "POST", "PUT", "PATCH", "DELETE"]

    var body: some View {
        HSplitView {
            listPane
                .frame(minWidth: 220, idealWidth: 260)
            editorPane
                .frame(minWidth: 360)
        }
        .frame(minWidth: 640, minHeight: 420)
        // Persist on any edit so the running addon picks it up live.
        .onChange(of: store.rules) { _ in store.save() }
    }

    // MARK: - List

    private var listPane: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(store.rules) { rule in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(rule.enabled ? Color.green : Color.secondary)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rule.endpoint.isEmpty ? "(no endpoint)" : rule.endpoint)
                                .lineLimit(1)
                            Text("\(rule.method ?? "ANY") · \(rule.statusCode)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(rule.id)
                }
                .onDelete { offsets in
                    store.rules.remove(atOffsets: offsets)
                }
            }

            Divider()

            HStack {
                Button {
                    selection = store.addRule().id
                } label: {
                    Image(systemName: "plus")
                }
                Button {
                    if let id = selection { store.delete(id: id); selection = nil }
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selection == nil)
                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(6)
        }
    }

    // MARK: - Editor

    @ViewBuilder
    private var editorPane: some View {
        if let index = store.rules.firstIndex(where: { $0.id == selection }) {
            editor(for: $store.rules[index])
        } else {
            VStack(spacing: 8) {
                Image(systemName: "arrow.left.circle")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("Select or add a rule")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func editor(for rule: Binding<OverrideRule>) -> some View {
        let bodyIsValid = Self.isValidJSON(rule.wrappedValue.responseBody)

        return VStack(alignment: .leading, spacing: 12) {
            Toggle("Enabled", isOn: rule.enabled)

            VStack(alignment: .leading, spacing: 4) {
                Text("Endpoint (URL contains)").font(.caption).foregroundColor(.secondary)
                TextField("/api/v1/users", text: rule.endpoint)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Method").font(.caption).foregroundColor(.secondary)
                    Picker("", selection: Binding(
                        get: { rule.wrappedValue.method ?? "ANY" },
                        set: { rule.wrappedValue.method = ($0 == "ANY") ? nil : $0 }
                    )) {
                        ForEach(Self.methods, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Status code").font(.caption).foregroundColor(.secondary)
                    TextField("200", value: rule.statusCode, format: .number.grouping(.never))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Response body (JSON)").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Label(bodyIsValid ? "Valid JSON" : "Invalid JSON",
                          systemImage: bodyIsValid ? "checkmark.circle" : "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(bodyIsValid ? .green : .orange)
                }
                TextEditor(text: rule.responseBody)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 160)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.3))
                    )
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private static func isValidJSON(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }
}
