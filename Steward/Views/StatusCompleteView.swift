import SwiftData
import SwiftUI

struct StatusCompleteView<Content: View>: View {
  @ViewBuilder let content: () -> Content

  @Environment(\.dismiss) private var dismiss

  init(@ViewBuilder _ content: @escaping () -> Content) {
    self.content = content
  }

  var body: some View {
    VStack {
      Image(systemName: "party.popper.fill").symbolRenderingMode(.hierarchical).font(.largeTitle)
        .foregroundStyle(.blue.gradient).symbolEffect(.wiggle, options: .nonRepeating)
      Spacer()
      content()
    }.padding()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Dismiss") { dismiss() }.keyboardShortcut(.defaultAction)
        }
      }.padding(EdgeInsets(top: 20, leading: 40, bottom: 20, trailing: 40))
  }
}

#Preview {
  StatusCompleteView {
    Text("Success")
  }
}
