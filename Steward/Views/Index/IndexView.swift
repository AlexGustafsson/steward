import SwiftData
import SwiftUI
import os

private let systemLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier!, category: "UI/IndexView")

struct IndexView: View {
  private enum IndexViewState: Equatable {
    case idle
    case indexing(Task<[IndexEntry], Error>)
    case indexed
    case error(String)
  }

  private enum IndexViewSheet: Hashable, Identifiable {
    case indexProgress
    case error(String)
    case success

    var id: Self {
      self
    }
  }

  @State private var state: IndexViewState = .idle
  @State private var sheet: IndexViewSheet? = nil

  @State private var url: URL? = nil
  @State private var entries: [IndexEntry] = []

  // TODO: Should essentially be index then viewindex view to allow for export / upload
  // TODO: Similar to upload view (confirm index view?)
  var body: some View {
    Group {
      if self.state == .idle {
        SelectFoldersView(title: "Drag and drop folders to index") { urls in
          let url = urls.first!
          do {
            let task = try StewardTool.index(roots: [url])
            self.state = .indexing(task)
            self.sheet = .indexProgress
            Task {
              do {
                self.entries = try await task.value
                self.url = url
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
        EntriesView(entries: $entries, sarifRules: nil) {
          Button("Cancel") {
            self.entries = []
            self.state = .idle
            self.sheet = nil
          }.keyboardShortcut(.cancelAction)
          Button("Export") {
            do {
              try saveIndex(entries: self.entries)
              self.sheet = .success
            } catch {
              systemLogger.error("Failed to save index: \(error, privacy: .public)")
              self.sheet = .error("Failed to save index: \(error.localizedDescription)")
            }
          }.keyboardShortcut(.defaultAction)
        }
      }
    }.sheet(item: $sheet) {
      switch state {
      case .indexing(let task):
        task.cancel()
        self.state = .idle
      default:
        break
      }

      self.sheet = nil
    } content: { sheet in
      switch sheet {
      case .indexProgress:
        StatusView(progress: .unknown, status: "Indexing")
      case .error(let error):
        StatusFailedView(text: error)
      case .success:
        StatusCompleteView {
          VStack {
            Text("Index saved successfully").foregroundColor(.blue)
          }
        }
      }
    }
  }
}

#Preview {
  IndexView()
}
