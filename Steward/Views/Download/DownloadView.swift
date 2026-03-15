import SwiftData
import SwiftUI
import os

private let systemLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier!, category: "UI/DownloadView")

struct DownloadView: View {
  private enum DownloadViewState: Equatable {
    case idle
    case indexing(Task<[IndexEntry], Error>)
    case filtering(Task<[IndexEntry], Error>)
    case indexed
    case downloading(Task<Void, Error>)
    case success
  }

  private enum DownloadViewSheet: Hashable, Identifiable {
    case indexProgress
    case filterProgress
    case downloadProgress
    case success
    case error(String)

    var id: Self {
      self
    }
  }

  @State private var state: DownloadViewState = .idle
  @State private var sheet: DownloadViewSheet? = nil

  @State private var entries: [IndexEntry] = []
  @State private var downloadProgress: StewardTool.DownloadProgress? = nil

  var body: some View {
    if self.state == .idle {
      SelectIndexView(title: "Drag and drop index to download") { reference in
        do {
          let task: Task<[IndexEntry], Error>
          switch reference {
          case .url(let url):
            task = try readIndex(from: url)
          case .code(let code):
            task = try StewardTool.downloadIndex(id: code)
          }
          self.state = .indexing(task)
          self.sheet = .indexProgress
          Task {
            do {
              self.entries = try await task.value
              self.state = .indexed
              self.sheet = nil
            } catch {
              systemLogger.error("Failed to index: \(error, privacy: .public)")
              self.sheet = .error("Failed to index: \(error.localizedDescription)")
            }
          }
        } catch {
          systemLogger.error("Failed to index: \(error, privacy: .public)")
          self.sheet = .error("Failed to index: \(error.localizedDescription)")
        }
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
                self.sheet = .error(
                  "Refusing to download to a non-empty directory. Select another directory or enable force."
                )
                return
              }
            }

            do {
              self.downloadProgress = nil
              let task = try StewardTool.download(
                root: panel.url!, entries: self.entries, force: force
              ) { progress in
                self.downloadProgress = progress
              }
              self.state = .downloading(task)
              self.sheet = .downloadProgress
              Task {
                do {
                  let _ = try await task.value
                  self.state = .success
                  self.sheet = .success
                } catch {
                  systemLogger.error("Failed to download: \(error, privacy: .public)")
                  self.sheet = .error("Failed to download: \(error.localizedDescription)")
                }
              }
            } catch {
              systemLogger.error("Failed to download: \(error, privacy: .public)")
              self.sheet = .error("Failed to download: \(error.localizedDescription)")
            }
          } else {
            self.entries = []
            self.state = .idle
            self.sheet = nil
          }
        }
      ).toolbar {
        ToolbarItem {
          Button {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowedContentTypes = [.json, .gzip]
            if panel.runModal() == .OK {
              do {
                let task = try StewardTool.diff(local: panel.url!, remote: entries)
                self.state = .filtering(task)
                self.sheet = .filterProgress
                Task {
                  do {
                    self.entries = try await task.value
                    self.state = .indexed
                    self.sheet = nil
                  } catch {
                    systemLogger.error("Failed to diff: \(error, privacy: .public)")
                    self.sheet = .error("Failed to diff: \(error.localizedDescription)")
                  }
                }
              } catch {
                systemLogger.error("Failed to diff: \(error, privacy: .public)")
                self.sheet = .error("Failed to diff: \(error.localizedDescription)")
              }
            }
          } label: {
            Image(systemName: "pencil.and.list.clipboard")
          }.help(Text("Diff against local index"))
        }
      }.sheet(item: $sheet) {
        switch state {
        case .indexing(let task):
          task.cancel()
          self.state = .idle
        case .filtering(let task):
          task.cancel()
          self.state = .indexed
        case .downloading(let task):
          task.cancel()
          self.state = .indexed
        case .success:
          self.state = .idle
          self.entries = []
        default:
          break
        }
        self.sheet = nil
      } content: { sheet in
        switch sheet {
        case .indexProgress:
          StatusView(progress: .unknown, status: "Indexing")
        case .filterProgress:
          StatusView(progress: .unknown, status: "Filtering")
        case .downloadProgress:
          StatusView(
            progress: .known(
              self.downloadProgress?.successes ?? 0, self.downloadProgress?.failures ?? 0,
              self.downloadProgress?.total ?? 0
            ),
            status: "Downloading")
        case .success:
          StatusCompleteView {
            Text("Download completed successfully.").foregroundColor(.blue)
          }
        case .error(let error):
          StatusFailedView(text: error)
        }
      }
    }
  }
}

#Preview {
  DownloadView()
}
