import SwiftData
import SwiftUI

struct IndexView: View {
  @State private var showIndexProgressSheet: Bool = false

  @State private var indexTask: Task<Void, Error>? = nil

  @State private var logs: [LogEntry] = []

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
          showIndexProgressSheet = true
          indexTask = try? StewardTool.index(roots: urls, to: savePanel.url!)
          Task {
            do {
              try await indexTask?.value
            } catch {
              print(error)
            }
            showIndexProgressSheet = false
          }
        }
      }
    }.sheet(isPresented: $showIndexProgressSheet) {
      self.indexTask?.cancel()
      self.indexTask = nil
    } content: {
      StatusView(progress: .unknown, status: "Indexing")
    }
  }
}

#Preview {
  IndexView()
}
