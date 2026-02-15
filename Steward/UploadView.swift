import SwiftUI
import SwiftData

struct UploadView: View {
    @State var filterURL: URL? = nil
    @State var urls: [URL]? = nil
    @State var entries: [Entry]? = nil
    
    @State private var showIndexProgressSheet: Bool = false
    @State private var showUploadProgressSheet: Bool = false
    @State private var showCompletedSheet: Bool = false
    @State private var showFailedSheet: Bool = false
    
    @State private var uploadProgress: Float = 0.0
    @State private var uploadStatus: String = ""
    
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
                StatusView(progress: .unknown, status: "Indexing")
            }.sheet(isPresented: $showCompletedSheet) {
                // TODO
            } content: {
                StatusCompleteView()
            }
        } else {
            ConfirmEntriesView(entries: entries!, confirmLabel: "Upload", action: { confirmed in
                if confirmed {
                    self.showUploadProgressSheet = true
                    
                    // TODO
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        self.showUploadProgressSheet = false
                        self.showCompletedSheet = true
                        self.entries = nil
                        self.urls = nil
                        withAnimation {
                            self.uploadProgress = 1.0
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            self.uploadProgress = 0.5
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation {
                            self.uploadProgress = 0.6
                        }
                    }
                } else {
                    self.entries = nil
                    self.urls = nil
                    self.showUploadProgressSheet = false
                }
            }).toolbar {
                ToolbarItem( placement: .cancellationAction ) {
                    Button {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = false
                        panel.canChooseFiles = true
                        panel.allowedContentTypes = [.json, .gzip]
                         if panel.runModal() == .OK {
                             filterURL = panel.url
                         }
                    } label: {
                        Image(systemName: "pencil.and.list.clipboard")
                    }
                }
            }.sheet(isPresented: $showUploadProgressSheet) {
                // TODO
                print("Sheet dismissed!")
            } content: {
                StatusView(progress: .known(self.uploadProgress), status: "Uploading")
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
