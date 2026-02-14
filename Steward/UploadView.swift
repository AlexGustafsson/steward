import SwiftUI
import SwiftData

struct UploadView: View {
    @State var urls: [URL]? = nil
    @State var entries: [Entry]? = nil
    
    @State var showIndexProgressSheet: Bool = false
    @State var showUploadProgressSheet: Bool = false
    @State var showCompletedSheet: Bool = false
    @State var showFailedSheet: Bool = false
    
    var body: some View {
        if entries == nil {
            SelectFoldersView(title: "Drag and drop folders to upload") { urls in
                self.urls = urls
                self.showIndexProgressSheet = true
                
                // TODO: Read and set self.entries
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.showIndexProgressSheet = false
                    self.entries =  [
                        Entry(id: "/user/alexg/1", disc: "1", track: "1", title: "Foo", album: "Wet wet wet", artist: "Wet wet wet", composer: nil),
                        Entry(id: "/user/alexg/2", disc: "1", track: "2", title: "Bar", album: "Wet wet wet", artist: "Wet wet wet", composer: nil),
                    ];
                }
            }.sheet(isPresented: $showIndexProgressSheet) {
                // TODO
                print("Dismissed")
            } content: {
                ProgressView().padding(20)
            }.sheet(isPresented: $showCompletedSheet) {
                // TODO
            } content: {
                Text("Done!")
            }
        } else {
            ConfirmEntriesView(entries: entries!, action: { confirmed in
                if confirmed {
                    self.showUploadProgressSheet = true
                    
                    // TODO
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.showUploadProgressSheet = false
                        self.showCompletedSheet = true
                        self.entries = nil
                        self.urls = nil
                    }
                } else {
                    self.entries = nil
                    self.urls = nil
                    self.showUploadProgressSheet = false
                }
            }).sheet(isPresented: $showUploadProgressSheet) {
                // TODO
                print("Sheet dismissed!")
            } content: {
                VStack {
                    ProgressView().padding(20)
                }
            }.sheet(isPresented: $showFailedSheet) {
                // TODO
            } content: {
                Text("Failed!")
            }
        }
    }
}

#Preview {
    UploadView()
}
