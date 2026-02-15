import SwiftUI
import SwiftData

struct SelectIndexView: View {
    public var title: String

    @State private var isHovering: Bool = false
    
    let action: (URL) -> Void
    
    init(title: String, action: @escaping (URL) -> Void) {
        self.title = title
        self.action = action
    }
   
    var body: some View {
        ZStack {
            Rectangle().stroke(style: StrokeStyle(lineWidth: 2, dash: [5])).foregroundStyle(.gray)
            VStack {
                Image(systemName: "arrow.up.document").font(.largeTitle).foregroundStyle(.gray)
                Text(title).font(.largeTitle).foregroundStyle(.gray)
                Button("Select index") {
                  let panel = NSOpenPanel()
                   panel.allowsMultipleSelection = false
                   panel.canChooseDirectories = false
                    panel.canChooseFiles = true
                    panel.allowedContentTypes = [.json, .gzip]
                   if panel.runModal() == .OK {
                       action(panel.url!)
                   }
                }.foregroundStyle(.blue)
            }
        }.padding(EdgeInsets(top: 20, leading: 30, bottom: 30, trailing: 40))
        .background(isHovering ? .blue.opacity(0.02) : .clear)
        .dropDestination(for: URL.self) { urls, _ in
            self.action(urls.first!)
            return true
        } isTargeted: { targeted in
            // TODO: Validate only one used?
            withAnimation {
                isHovering = targeted
            }
        }
    }
}

#Preview {
    @Previewable @State var urls = false
    
    SelectFoldersView(title: "Drag and drop folders") { urls in
        print(urls)
    }
}
