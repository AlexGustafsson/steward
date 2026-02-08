import SwiftUI
import SwiftData

struct DownloadView: View {
    @Binding var inProgress: Bool

    @State var downloading = false

    @State var urls: [URL] = []
    @State var isDropTargeted = false

    var body: some View {
            ZStack {
                Rectangle().stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                VStack {
                    Image(systemName: "arrow.up.folder").font(.largeTitle).foregroundStyle(.blue)
                    Text("Drag and drop index").font(.largeTitle)
                    Button("Select index") {
                        let panel = NSOpenPanel()
                       panel.allowsMultipleSelection = true
                       panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                       if panel.runModal() == .OK {
                           self.urls = panel.urls
                           self.inProgress = true
                           self.downloading = true
                       }
                    }.foregroundStyle(.blue)
                }
            }.padding(EdgeInsets(top: 20, leading: 30, bottom: 30, trailing: 40))
            .dropDestination(for: URL.self) { urls, _ in
                print("got \(urls)")
                // TODO: Validate URL
                self.urls = urls
                return true
            } isTargeted: { targeted in
                isDropTargeted = targeted
            }
            // .onDrop(of: ["public.url","public.file-url"], isTargeted: nil) { (items) -> Bool in
            //             if let item = items.first {
            //                 if let identifier = item.registeredTypeIdentifiers.first {
            //                     print("onDrop with identifier = \(identifier)")
            //                     if identifier == "public.url" || identifier == "public.file-url" {
            //                         item.loadItem(forTypeIdentifier: identifier, options: nil) { (urlData, error) in
            //                                 if let urlData = urlData as? Data {
            //                                     let urll = NSURL(absoluteURLWithDataRepresentation: urlData, relativeTo: nil) as URL
            //                                     print("got \(urll)")
            //                                 }
            //                         }
            //                     }
            //                 }
            //                 return true
            //             } else { print("item not here"); return false }
            //         }
            .sheet(isPresented: $downloading) {
                print("Sheet dismissed!")
            } content: {
                VStack {
                    ProgressView().padding(20)
                    ScrollView {
                        Text("Logs will show here")
                    }.scrollIndicators(.visible)

                    Spacer()
                    HStack {
                        Spacer()
                        Button("Cancel", role: .destructive) {
                            downloading = false
                        }.foregroundStyle(.red)
                    }
                }
        }
    }
}

#Preview {
    @Previewable @State var inProgress = false
    DownloadView(inProgress: $inProgress)
}
