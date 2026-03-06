import SwiftData
import SwiftUI

struct DownloadView: View {
  @State var indexTask: Task<[IndexEntry], Error>? = nil
  @State var entries: [IndexEntry] = []

  @State var filterTask: Task<[IndexEntry], Error>? = nil
  @State var downloadTask: Task<Void, Error>? = nil

  @State var outputURL: URL? = nil

  @State private var showDownloadProgressSheet: Bool = false
  @State private var showCompletedSheet: Bool = false
  @State private var showFailedSheet: Bool = false

  @State private var downloadProgress: Float = 0.0
  @State private var downloadStatus: String = ""

  @State private var logs: [LogEntry] = []

  var body: some View {
    if entries.count == 0 {
      SelectIndexView(title: "Drag and drop index to download") { url in
        do {
          self.logs = []
          self.indexTask = try readIndex(from: url)
          Task {
            do {
              self.entries = try await self.indexTask!.value
            } catch {
              print(error)
            }
            self.indexTask = nil
            self.logs = []
          }
        } catch {
          print(error)
        }
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
            panel.canCreateDirectories = true
            if panel.runModal() != .OK {
              return
            }

            self.downloadProgress = 0.0
            self.showDownloadProgressSheet = true

            do {
              // TODO: Progress reporting
              self.downloadTask = try StewardTool.download(root: panel.url!, entries: self.entries)
              Task {
                do {
                  let _ = try await self.downloadTask?.value
                  self.showCompletedSheet = true
                  self.entries = []
                  withAnimation {
                    self.downloadProgress = 1.0
                  }
                } catch {
                  self.showFailedSheet = true
                  print(error)
                }
                self.downloadTask = nil
                self.showDownloadProgressSheet = false
              }
            } catch {
              print(error)
              return
            }
          } else {
            self.entries = []
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
              do {
                self.filterTask = try StewardTool.diff(local: panel.url!, remote: entries)
                Task {
                  do {
                    self.entries = try await self.filterTask!.value
                  } catch {
                    print(error)
                  }
                  self.filterTask = nil
                }
              } catch {
                print(error)
              }
            }
          } label: {
            Image(systemName: "pencil.and.list.clipboard")
          }
        }
      }.sheet(isPresented: $showDownloadProgressSheet) {
        self.downloadTask?.cancel()
        self.downloadTask = nil
      } content: {
        StatusView(progress: .known(self.downloadProgress), status: "Downloading", logs: logs)
      }.sheet(isPresented: $showFailedSheet) {
        self.showFailedSheet = false
      } content: {
        // LogTable(logs: logs).frame(width: 500, height: 400)
      }
    }
  }
}

#Preview {
  UploadView()
}
