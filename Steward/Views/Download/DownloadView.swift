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
  @State private var showNonEmptyDirectory: Bool = false

  @State private var downloadProgress: StewardTool.DownloadProgress? = nil

  var body: some View {
    if entries.count == 0 {
      SelectIndexView(title: "Drag and drop index to download") { url in
        do {
          self.indexTask = try readIndex(from: url)
          Task {
            do {
              self.entries = try await self.indexTask!.value
            } catch {
              print(error)
            }
            self.indexTask = nil
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
        action: { confirmed, force in
          if confirmed {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.canCreateDirectories = true
            if panel.runModal() != .OK {
              return
            }

            if !force {
              let isEmpty =
                FileManager.default.enumerator(atPath: panel.url!.path(percentEncoded: false))?
                .nextObject() == nil
              if !isEmpty {
                showNonEmptyDirectory = true
                return
              }
            }

            self.downloadProgress = nil
            self.showDownloadProgressSheet = true

            do {
              // TODO: Progress reporting
              self.downloadTask = try StewardTool.download(
                root: panel.url!, entries: self.entries, force: force
              ) { progress in
                self.downloadProgress = progress
              }
              Task {
                do {
                  let _ = try await self.downloadTask?.value
                  self.showCompletedSheet = true
                  self.entries = []
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
        StatusView(
            progress: .known(self.downloadProgress?.processedEntries ?? 0, self.downloadProgress?.totalEntries ?? 0),
          status: "Downloading")
      }.sheet(isPresented: $showFailedSheet) {
        self.showFailedSheet = false
      } content: {
        // LogTable(logs: logs).frame(width: 500, height: 400)
      }.sheet(isPresented: $showNonEmptyDirectory) {
        self.showNonEmptyDirectory = false
      } content: {
        Text(
          "Refusing to download to a non-empty directory. Select another directory or enable force."
        ).padding()
      }
    }
  }
}

#Preview {
  UploadView()
}
