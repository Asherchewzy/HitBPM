import SwiftUI

struct TargetHeartRateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var text: String
    let onSave: (Int) -> Void

    init(target: Int?, onSave: @escaping (Int) -> Void) {
        _text = State(initialValue: target.map(String.init) ?? "")
        self.onSave = onSave
    }

    private var target: Int? {
        guard let value = Int(text.trimmingCharacters(in: .whitespaces)), value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Target BPM", text: $text)
                    .keyboardType(.numberPad)
                    .focused($isFocused)
                    .accessibilityLabel("Target heart rate in beats per minute")
                if target == nil {
                    Text("Enter a positive whole number.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Target heart rate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(target == nil)
                }
            }
            .onAppear { isFocused = true }
        }
    }

    private func save() {
        guard let target else { return }
        onSave(target)
        dismiss()
    }
}
