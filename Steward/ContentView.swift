import SwiftUI
import SwiftData

struct ContentView: View {
    @State var selection = "upload"
    @State var inProgress = false

    var body: some View {
         TabView(selection: Binding(
            get: { selection },
            set: { newValue in
                if !inProgress {
                    selection = newValue
                }
            }
        )) {
             UploadView().tabItem{ Label("Upload", systemImage: "list.bullet").foregroundColor(inProgress ? .secondary : .primary) }.tag("upload")
             DownloadView(inProgress: $inProgress).tabItem{ Label("Download", systemImage: "list.bullet").foregroundColor(inProgress ? .secondary : .primary) }.tag("download")
             IndexView().tabItem{ Label("Index", systemImage: "list.bullet").foregroundColor(inProgress ? .secondary : .primary) }.tag("index")
         }
    }
}

#Preview {
    ContentView()
}
