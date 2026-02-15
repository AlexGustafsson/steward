import SwiftUI
import SwiftData

struct IndexView: View {
    @State private var showIndexProgressSheet: Bool = false
    
    var body: some View {
            SelectFoldersView(title: "Drag and drop folders to index")  { urls in
                let savePanel = NSSavePanel()
                savePanel.canCreateDirectories = true
                savePanel.showsContentTypes = true
                savePanel.showsTagField = false
                savePanel.nameFieldStringValue = "index"
                savePanel.allowedContentTypes = [.json]
                savePanel.begin { (result) in
                    if result == .OK {
                        showIndexProgressSheet = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            self.showIndexProgressSheet = false
                        }
                    }
                }
            }.sheet(isPresented: $showIndexProgressSheet) {
                // TODO
                print("Dismissed")
            } content: {
                StatusView(progress: .unknown, status: "Indexing")
            }
    }
}

#Preview {
    IndexView()
}
