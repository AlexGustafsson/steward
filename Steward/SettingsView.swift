import SwiftUI

struct SettingsView: View {
    @State private var newConfig = ""
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Configuration", text: $newConfig, prompt: Text("Config"))
                                      .textFieldStyle(.plain).labelsHidden()
                }
            }.padding(5).formStyle(.grouped)
            .formStyle(.grouped)
            Divider()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    
                }
                .keyboardShortcut(.defaultAction)
            }.padding(20)
        }.frame(width: 300, height: 200)
    }
}
