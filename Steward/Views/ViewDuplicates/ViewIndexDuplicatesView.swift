import SwiftData
import SwiftUI
import os

private let systemLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier!, category: "UI/ViewIndexView")

struct ViewIndexDuplicatesView: View {
  private enum ViewIndexDuplicatesViewState: Equatable {
    case idle
    case indexing(Task<[IndexEntry], Error>)
    case indexed
  }

  private enum ViewIndexDuplicatesViewSheet: Hashable, Identifiable {
    case indexProgress
    case error(String)
    case success

    var id: Self {
      self
    }
  }

  @State private var state: ViewIndexDuplicatesViewState = .idle
  @State private var sheet: ViewIndexDuplicatesViewSheet? = nil

  @State private var entries: [IndexEntry] = []

  var body: some View {
    Group {
      if self.state == .idle {
        SelectIndexView(title: "Drag and drop index to find duplicates") { reference in
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
                let entries = try await task.value
                let groups = Dictionary(grouping: entries, by: \.audioDigest)
                self.entries = groups.filter { $1.count > 1 }.flatMap({ $1 })
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
  ViewIndexView()
}
