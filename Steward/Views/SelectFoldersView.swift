import SwiftUI
import SwiftData

struct SelectFoldersView: View {
    public var title: String

    @State private var isHovering: Bool = false
    
    @Environment(\.isEnabled) private var isEnabled
    
    let action: ([URL]) -> Void
    
    init(title: String, action: @escaping ([URL]) -> Void) {
        self.title = title
        self.action = action
    }
   
    var body: some View {
        ZStack {
            Rectangle().stroke(style: StrokeStyle(lineWidth: 2, dash: [5])).foregroundStyle(.gray.opacity(isEnabled ? 1.0 : 0.3))
            VStack {
                Image(systemName: "arrow.up.folder").font(.largeTitle).foregroundStyle(.gray.opacity(isEnabled ? 1.0 : 0.3))
                Text(title).font(.largeTitle).foregroundStyle(.gray.opacity(isEnabled ? 1.0 : 0.3))
                Button("Select folders") {
                  let panel = NSOpenPanel()
                   panel.allowsMultipleSelection = true
                   panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                   if panel.runModal() == .OK {
                       action(panel.urls)
                   }
                }.foregroundStyle(.blue)
            }
        }.padding(EdgeInsets(top: 20, leading: 30, bottom: 30, trailing: 40))
        .background(isHovering ? .blue.opacity(0.02) : .clear)
        .dropDestination(for: URL.self) { urls, _ in
            self.action(urls)
            return true
        } isTargeted: { targeted in
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
