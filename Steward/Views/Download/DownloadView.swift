import SwiftData
import SwiftUI

struct DownloadView: View {
  @State var outputURL: URL? = nil
  @State var filterURL: URL? = nil
  @State var url: URL? = nil
  @State var entries: [Entry]? = nil

  @State private var showDownloadProgressSheet: Bool = false
  @State private var showCompletedSheet: Bool = false
  @State private var showFailedSheet: Bool = false

  @State private var downloadProgress: Float = 0.0
  @State private var downloadStatus: String = ""

  var body: some View {
    if entries == nil {
      SelectIndexView(title: "Drag and drop index to download") { url in
        self.url = url

        // TODO: Read and set self.entries
        self.entries = [
          Entry(
            id: "/user/alexg/1", disc: "1", track: "1", title: "Foo", album: "Wet wet wet",
            artist: "Wet wet wet", composer: nil),
          Entry(
            id: "/user/alexg/2", disc: "1", track: "2", title: "Bar", album: "Wet wet wet",
            artist: "Wet wet wet", composer: nil),
        ]
      }.sheet(isPresented: $showCompletedSheet) {
        // TODO
      } content: {
        StatusCompleteView()
      }
    } else {
      ConfirmEntriesView(
        entries: entries!, confirmLabel: "Download",
        action: { confirmed in
          if confirmed {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            if panel.runModal() != .OK {
              return
            }

            self.outputURL = panel.url

            self.showDownloadProgressSheet = true

            // TODO: Download

            // TODO
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
              self.showDownloadProgressSheet = false
              self.showCompletedSheet = true
              self.entries = nil
              self.url = nil
              withAnimation {
                self.downloadProgress = 1.0
              }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
              withAnimation {
                self.downloadProgress = 0.5
              }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
              withAnimation {
                self.downloadProgress = 0.6
              }
            }
          } else {
            self.entries = nil
            self.url = nil
            self.showDownloadProgressSheet = false
          }
        }
      ).toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowedContentTypes = [.json, .gzip]
            if panel.runModal() == .OK {
              filterURL = panel.url
            }
          } label: {
            Image(systemName: "pencil.and.list.clipboard")
          }
        }
      }.sheet(isPresented: $showDownloadProgressSheet) {
        // TODO
        print("Sheet dismissed!")
      } content: {
        StatusView(progress: .known(self.downloadProgress), status: "Downloading")
      }.sheet(isPresented: $showFailedSheet) {
        // TODO
      } content: {
        Text("Failed!")
      }
    }
  }
}

#Preview {
  UploadView()
}
