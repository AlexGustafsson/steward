import SwiftData
import SwiftUI

struct StatusFailedView: View {
  @State var text: String

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack {
      Image(systemName: "xmark.circle.fill").symbolRenderingMode(.hierarchical).font(.largeTitle)
        .foregroundStyle(.red.gradient).symbolEffect(.wiggle, options: .nonRepeating)
      Spacer()
      Text(text).foregroundStyle(.red)
    }.padding()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Dismiss") { dismiss() }.keyboardShortcut(.defaultAction)
        }
      }.padding(EdgeInsets(top: 20, leading: 40, bottom: 20, trailing: 40))
  }
}

#Preview {
  StatusFailedView(text: "Failure")
}
