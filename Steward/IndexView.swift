import SwiftUI
import SwiftData

struct IndexView: View {
    @State private var index: String? = ""
    
    @State private var showIndexProgressSheet: Bool = false
    
    var body: some View {
            SelectFoldersView(title: "Drag and drop folders to index")  { urls in
                showIndexProgressSheet = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.showIndexProgressSheet = false
                    self.index = ""
                    
                    let savePanel = NSSavePanel()
                    savePanel.canCreateDirectories = true
                    savePanel.showsContentTypes = true
                    savePanel.showsTagField = false
                    savePanel.nameFieldStringValue = "index.json"
                    savePanel.allowedContentTypes = [.json]
                    savePanel.begin { (result) in
                        if result == .OK {
                            self.index = nil
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
