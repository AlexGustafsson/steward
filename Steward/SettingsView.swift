import SwiftUI

struct SettingsView: View {
    @State private var newConfig = ""
    
    @AppStorage("configFileBookmark") private var configFileBookmark: Data = .init()
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Credentials") {
                    if configFileBookmark.isEmpty {
                        HStack{
                            Text("Not selected")
                            Spacer()
                            Button("Select") {
                                let panel = NSOpenPanel()
                                panel.canChooseFiles = true
                                panel.canChooseDirectories = false
                                if panel.runModal() == .OK {
                                    do {
                                        let bookmark = try panel.url!.bookmarkData(options:  [.withSecurityScope, .securityScopeAllowOnlyReadAccess])
                                        configFileBookmark = bookmark
                                    } catch {
                                        print("failed to bookmark file")
                                    }
                                }
                            }
                        }
                    } else {
                        HStack{
                            Text("Selected")
                            Spacer()
                            Button("Remove") {
                                configFileBookmark = .init()
                            }.foregroundStyle(.red)
                            Button("Replace") {
                                let panel = NSOpenPanel()
                                panel.canChooseFiles = true
                                panel.canChooseDirectories = false
                                if panel.runModal() == .OK {
                                    do {
                                        let bookmark = try panel.url!.bookmarkData(options:  [.withSecurityScope, .securityScopeAllowOnlyReadAccess])
                                        configFileBookmark = bookmark
                                    } catch {
                                        print("failed to bookmark file")
                                    }
                                }
                            }
                        }
                    }
                }
            }.padding(5).formStyle(.grouped)
            .formStyle(.grouped)
            Divider()
            HStack {
                Spacer()
                Button("Ok") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }.padding(20)
        }.frame(width: 300, height: 200)
    }
}
