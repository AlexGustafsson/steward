import SwiftData
import SwiftUI

struct DownloadView: View {
  @State var outputURL: URL? = nil
  @State var filterURL: URL? = nil
  @State var url: URL? = nil
  @State var entries: [IndexEntry] = []

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
            IndexEntry(name: "/user/alex/1", modTime: .now, size: 30000000, metadata: ["ALBUM=Wet wet wet"], audioDigest: "md5:b1946ac92492d2347c6235b4d2611184", pictureDigest: "md5:d41d8cd98f00b204e9800998ecf8427e"),
            IndexEntry(name: "/user/alex/2", modTime: .now, size: 30000000, metadata: ["ALBUM=We can't dance"], audioDigest: "md5:a10edbbb8f28f8e98ee6b649ea2556f4", pictureDigest: "md5:d41d8cd98f00b204e9800998ecf8427e")
          ]
      }.sheet(isPresented: $showCompletedSheet) {
        // TODO
      } content: {
        StatusCompleteView()
      }
    } else {
      ConfirmEntriesView(
        entries: $entries, confirmLabel: "Download",
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
              self.entries = []
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
            self.entries = []
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
