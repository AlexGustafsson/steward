import SwiftData
import SwiftUI
import os

private let systemLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier!, category: "UI/ViewIndexView")

struct ViewIndexView: View {
  private enum ViewIndexViewState: Equatable {
    case idle
    case indexing(Task<[IndexEntry], Error>)
    case indexed
  }

  private enum ViewIndexViewSheet: Hashable, Identifiable {
    case indexProgress
    case error(String)

    var id: Self {
      self
    }
  }

  @State private var state: ViewIndexViewState = .idle
  @State private var sheet: ViewIndexViewSheet? = nil

  @State private var entries: [IndexEntry] = []

  var body: some View {
    if self.state == .idle {
      SelectIndexView(title: "Drag and drop index to show") { reference in
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
        }
      }
    } else {
      VStack {
        EntriesTable(entries: $entries)
        Divider()
        HStack {
          Spacer()
          Button("Cancel") {
            self.entries = []
            self.state = .idle
            self.sheet = nil
          }
        }.padding()
      }
    }
  }
}

#Preview {
  ViewIndexView()
}
