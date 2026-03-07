import SwiftData
import SwiftUI
import os

private let systemLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier!, category: "UI/IndexView")

struct IndexView: View {
  private enum IndexViewState: Equatable {
    case idle
    case indexing(Task<Void, Error>)
    case error(String)
  }

  private enum IndexViewSheet: Hashable, Identifiable {
    case indexProgress
    case error(String)

    var id: Self {
      self
    }
  }

  @State private var state: IndexViewState = .idle
  @State private var sheet: IndexViewSheet? = nil

  var body: some View {
    SelectFoldersView(title: "Drag and drop folders to index") { urls in
      let savePanel = NSSavePanel()
      savePanel.canCreateDirectories = true
      savePanel.showsContentTypes = true
      savePanel.showsTagField = false
      savePanel.nameFieldStringValue = "index"
      savePanel.allowedContentTypes = [.json]
      savePanel.begin { (result) in
        if result == .OK {
          do {
            let task = try StewardTool.index(roots: urls, to: savePanel.url!)
            self.state = .indexing(task)
            self.sheet = .indexProgress
            Task {
              do {
                let _ = try await task.value
                self.state = .idle
                self.sheet = nil
              } catch {
                systemLogger.error("Failed to index: \(error, privacy: .public)")
                self.state = .error("Failed to index: \(error.localizedDescription)")
                self.sheet = .error("Failed to index: \(error.localizedDescription)")
              }
            }
          } catch {
            systemLogger.error("Failed to index: \(error, privacy: .public)")
            self.state = .error("Failed to index: \(error.localizedDescription)")
            self.sheet = .error("Failed to index: \(error.localizedDescription)")
          }
        }
      }
    }.sheet(item: $sheet) {
      switch state {
      case .indexing(let task):
        task.cancel()
      default:
        break
      }

      self.state = .idle
      self.sheet = nil
    } content: { sheet in
      switch sheet {
      case .indexProgress:
        StatusView(progress: .unknown, status: "Indexing")
      case .error(let error):
        StatusFailedView(text: error)
      }
    }
  }
}

#Preview {
  IndexView()
}
