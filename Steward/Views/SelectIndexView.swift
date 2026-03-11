import SwiftData
import SwiftUI

enum IndexReference {
  case url(URL)
  case code(String)
}

struct SelectIndexView: View {
  public var title: String

  @State private var isHovering: Bool = false
  @State private var showSheet: Bool = false
  @State private var code: String = ""

  @Environment(\.isEnabled) private var isEnabled

  let action: (IndexReference) -> Void

  init(title: String, action: @escaping (IndexReference) -> Void) {
    self.title = title
    self.action = action
  }

  var body: some View {
    ZStack {
      Rectangle().stroke(style: StrokeStyle(lineWidth: 2, dash: [5])).foregroundStyle(
        .gray.opacity(isEnabled ? 1.0 : 0.3))
      VStack {
        Image(systemName: "arrow.up.document").font(.largeTitle).foregroundStyle(
          .gray.opacity(isEnabled ? 1.0 : 0.3))
        Text(title).font(.largeTitle).foregroundStyle(.gray.opacity(isEnabled ? 1.0 : 0.3))
        HStack {
          Button("Enter code") {
            showSheet = true
          }
          Button("Select index") {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowedContentTypes = [.json, .gzip]
            if panel.runModal() == .OK {
              action(.url(panel.url!))
            }
          }.foregroundStyle(.blue)
        }
      }
    }.padding(EdgeInsets(top: 20, leading: 30, bottom: 30, trailing: 40))
      .background(isHovering ? .blue.opacity(0.02) : .clear)
      .dropDestination(for: URL.self) { urls, _ in
        self.action(.url(urls.first!))
        return true
      } isTargeted: { targeted in
        // TODO: Validate only one used?
        withAnimation {
          isHovering = targeted
        }
      }.sheet(isPresented: $showSheet) {
        showSheet = false
        code = ""
      } content: {
        VStack {
          TextField("Code", text: $code, prompt: Text("Code"))
            .padding()
          Divider()
          HStack {
            Spacer()
            Button("Cancel") {
              showSheet = false
              code = ""
            }.keyboardShortcut(.cancelAction)
            Button("Submit") {
              showSheet = false
              action(.code(code))
              code = ""
            }.keyboardShortcut(.defaultAction).disabled(!(code.hasPrefix("_:") || code.count == 9))
          }.padding()
        }
      }
  }
}

#Preview {
  @Previewable @State var urls = false

  SelectIndexView(title: "Drag and drop index to download") { urls in
    print(urls)
  }
}
