import SwiftData
import SwiftUI

struct ContentView: View {
  @State var selection = "upload"
  @State var inProgress = false

  // TODO: Use a manager with a reactive property for this from the environnment.
  // Right now, the first time, the app needs to be restarted
  @State private var credentialsExist = try? CredentialsExist()

  var body: some View {
    NavigationSplitView {
      List {
        NavigationLink {
          UploadView()
        } label: {
          Label("Upload", systemImage: "arrow.up.circle")
        }

        NavigationLink {
          DownloadView()
        } label: {
          Label("Download", systemImage: "arrow.down.circle")
        }

        Text("Indexing").font(.subheadline)
        NavigationLink {
          IndexView()
        } label: {
          Label("Index", systemImage: "waveform.badge.magnifyingglass")
        }
        NavigationLink {
          ViewIndexView()
        } label: {
          Label("Show index", systemImage: "waveform.path.ecg.text.page")
        }
        NavigationLink {
          ViewIndexDuplicatesView()
        } label: {
          Label("Find duplicates", systemImage: "document.on.document")
        }
      }
    } detail: {
      Text("Default home")
    }
  }
}

#Preview {
  ContentView()
}
