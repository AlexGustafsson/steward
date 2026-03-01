import SwiftData
import SwiftUI

struct ContentView: View {
  @State var selection = "upload"
  @State var inProgress = false

  // TODO: Use a manager with a reactive property for this from the environnment.
  // Right now, the first time, the app needs to be restarted
  @State private var credentialsExist = try? CredentialsExist()

  var body: some View {
    TabView(
      selection: Binding(
        get: { selection },
        set: { newValue in
          if !inProgress {
            selection = newValue
          }
        }
      )
    ) {
      IndexView().tabItem {
        Label("Index", systemImage: "list.bullet").foregroundColor(
          inProgress ? .secondary : .primary)
      }.tag("index")
      UploadView().tabItem {
        Label("Upload", systemImage: "list.bullet").foregroundColor(
          inProgress ? .secondary : .primary)
      }.tag("upload").disabled(credentialsExist != true)
      DownloadView().tabItem {
        Label("Download", systemImage: "list.bullet").foregroundColor(
          inProgress ? .secondary : .primary)
      }.tag("download").disabled(credentialsExist != true)
    }
  }
}

#Preview {
  ContentView()
}
