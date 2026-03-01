import SwiftData
import SwiftUI

struct IndexView: View {
  @State private var showIndexProgressSheet: Bool = false

  private var indexer: Indexer = Indexer()

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
          self.indexer.index(roots: urls, outputPath: savePanel.url!) { _ in
            showIndexProgressSheet = false
          }
        }
      }
    }.sheet(isPresented: $showIndexProgressSheet) {
      self.indexer.cancel()
    } content: {
      StatusView(progress: .unknown, status: "Indexing")
    }
  }
}

#Preview {
  IndexView()
}
