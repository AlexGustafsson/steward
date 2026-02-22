import SwiftUI
import SwiftData

struct ContentView: View {
    @State var selection = "upload"
    @State var inProgress = false
    
    @AppStorage("configFileBookmark") private var configFileBookmark: Data = .init()

    var body: some View {
         TabView(selection: Binding(
            get: { selection },
            set: { newValue in
                if !inProgress {
                    selection = newValue
                }
            }
        )) {
            IndexView().tabItem{ Label("Index", systemImage: "list.bullet").foregroundColor(inProgress ? .secondary : .primary) }.tag("index")
            UploadView().tabItem{ Label("Upload", systemImage: "list.bullet").foregroundColor(inProgress ? .secondary : .primary) }.tag("upload").disabled(configFileBookmark.isEmpty)
             DownloadView().tabItem{ Label("Download", systemImage: "list.bullet").foregroundColor(inProgress ? .secondary : .primary) }.tag("download").disabled(configFileBookmark.isEmpty)
         }
    }
}

#Preview {
    ContentView()
}
