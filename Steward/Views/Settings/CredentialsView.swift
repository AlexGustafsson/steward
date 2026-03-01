import SwiftUI

struct CredentialsView: View {
  @Environment(\.dismiss) private var dismiss

  @State private var region = ""
  @State private var key = ""
  @State private var secret = ""
  @State private var bucket = ""

  var body: some View {
    VStack {
      Form {
        Section {
          VStack {
            TextField("Region", text: $region, prompt: Text("Region"))
            TextField("Key", text: $key, prompt: Text("Key"))
            TextField("Secret", text: $secret, prompt: Text("Secret"))
            TextField("Bucket", text: $bucket, prompt: Text("Bucket"))
          }
        }
      }.padding(5).formStyle(.grouped)
      Divider()
      HStack {
        Spacer()
        Button("Cancel") {
          dismiss()
        }
        .keyboardShortcut(.cancelAction)
        Button("Save") {
          do {
            try SetCredentials(
              Credentials(
                region: region,
                key: key,
                secret: secret,
                bucket: bucket,
              ))
          } catch {
            print(error)
            return
          }
          // TODO
          dismiss()
        }
        .keyboardShortcut(.defaultAction)
      }.padding(20)
    }
  }
}
