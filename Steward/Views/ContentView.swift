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

        NavigationLink(value: SidebarItem.upload) {
          Label("Upload", systemImage: "arrow.up.circle")
        }

        NavigationLink(value: SidebarItem.download) {
          Label("Download", systemImage: "arrow.down.circle")
        }

        Text("Indexing")
          .font(.subheadline)

        NavigationLink(value: SidebarItem.index) {
          Label("Index", systemImage: "waveform.badge.magnifyingglass")
        }

        NavigationLink(value: SidebarItem.showIndex) {
          Label("Show index", systemImage: "waveform.path.ecg.text.page")
        }

        NavigationLink(value: SidebarItem.duplicates) {
          Label("Find duplicates", systemImage: "document.on.document")
        }
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
