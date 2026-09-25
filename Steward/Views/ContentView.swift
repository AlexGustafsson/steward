import SwiftData
import SwiftUI

enum SidebarItem: Hashable {
  case upload
  case download
  case index
  case showIndex
  case duplicates
}

struct ContentView: View {
  @State private var selection: SidebarItem? = .upload

  // TODO: Use a manager with a reactive property for this from the environnment.
  // Right now, the first time, the app needs to be restarted
  @State private var credentialsExist = try? CredentialsExist()

  var body: some View {
    NavigationSplitView {
      List(selection: $selection) {
        Text("Backup")
          .font(.subheadline)

        Label("Upload", systemImage: "arrow.up.circle")
          .tag(SidebarItem.upload)

        Label("Download", systemImage: "arrow.down.circle")
          .tag(SidebarItem.download)

        Text("Indexing")
          .font(.subheadline)

        Label("Create index", systemImage: "waveform.badge.magnifyingglass")
          .tag(SidebarItem.index)

        Label("Show index", systemImage: "waveform.path.ecg.text.page")
          .tag(SidebarItem.showIndex)

        Label("Find duplicates", systemImage: "document.on.document")
          .tag(SidebarItem.duplicates)
      }
    } detail: {
      switch selection {
      case .upload:
        UploadView()
      case .download:
        DownloadView()
      case .index:
        IndexView()
      case .showIndex:
        ViewIndexView()
      case .duplicates:
        ViewIndexDuplicatesView()
      case nil:
        UploadView()
      }
    }
  }
}

#Preview {
  ContentView()
}
