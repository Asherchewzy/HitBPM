import SwiftUI

struct DurationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var minutes: Int
    @State private var seconds: Int
    let title: String
    let allowsZero: Bool
    let onSave: (Int) -> Void

    init(title: String, seconds: Int, allowsZero: Bool, onSave: @escaping (Int) -> Void) {
        self.title = title
        self.allowsZero = allowsZero
        self.onSave = onSave
        _minutes = State(initialValue: seconds / 60)
        _seconds = State(initialValue: seconds % 60)
    }

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Picker("Minutes", selection: $minutes) {
                        ForEach(0..<60) { Text("\($0) min").tag($0) }
                    }
                    Picker("Seconds", selection: $seconds) {
                        ForEach(0..<60) { Text("\($0) sec").tag($0) }
                    }
                }
                .pickerStyle(.wheel)
                if allowsZero {
                    Text("00:00 re-arms the heart-rate trigger immediately.")
                        .foregroundStyle(.secondary)
                } else if minutes == 0 && seconds == 0 {
                    Text("Choose a duration greater than zero.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!allowsZero && minutes == 0 && seconds == 0)
                }
            }
        }
    }

    private func save() {
        onSave(minutes * 60 + seconds)
        dismiss()
    }
}
