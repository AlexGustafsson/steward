import SwiftUI

struct SettingsView: View {
    @State private var newConfig = ""
    
    @State private var credentialsExist = try? CredentialsExist()
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var key = ""
    @State private var secret = ""
    @State private var bucket = ""
    
    @State private var showCredentialsModal = false
    
    var body: some View {
        VStack(spacing: 0) {
            Form {
                if credentialsExist == true {
                    Section("Credentials") {
                        HStack {
                            Text("Credentials have been configured.")
                            Spacer()
                            Button("Edit...") {
                                showCredentialsModal = true
                            }
                        }.sheet(isPresented: $showCredentialsModal) {
                            CredentialsView()
                        }
                    }
                } else {
                    Section("Credentials") {
                        HStack {
                            Text("Credentials have note yet been configured.")
                            Spacer()
                            Button("Set...") {
                                showCredentialsModal = true
                            }
                        }.sheet(isPresented: $showCredentialsModal) {
                            credentialsExist = try? CredentialsExist()
                        } content: {
                            CredentialsView()
                        }
                    }
                }
            }.padding(5).formStyle(.grouped)
            Divider()
            HStack {
                Spacer()
                Button("Ok") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }.padding(20)
        }.frame(width: 400, height: 300)
    }
}
