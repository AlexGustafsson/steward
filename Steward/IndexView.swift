import SwiftUI
import SwiftData

struct IndexView: View {
    @Binding var inProgress: Bool
    
    var body: some View {
        SelectFoldersView(title: "Drag and drop folders to index")  { urls in
            print(urls)
    }
    }
}

#Preview {
    @Previewable @State var inProgress = false
    IndexView(inProgress: $inProgress)
}
