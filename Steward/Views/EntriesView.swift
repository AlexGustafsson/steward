import SwiftData
import SwiftUI

struct EntriesView<Options: View, Actions: View>: View {
  @Binding private var entries: [IndexEntry]
  private var sarifRules: [String: SarifRule]?

  private let options: Options
  private let actions: Actions

  init(
    entries: Binding<[IndexEntry]>, sarifRules: [String: SarifRule]?,
    @ContentBuilder actions: () -> Actions
  )
  where Options == EmptyView {
    self._entries = entries
    self.sarifRules = sarifRules
    self.options = EmptyView()
    self.actions = actions()
  }

  init(
    entries: Binding<[IndexEntry]>, sarifRules: [String: SarifRule]?,
    @ContentBuilder options: () -> Options,
    @ContentBuilder actions: () -> Actions
  ) {
    self._entries = entries
    self.sarifRules = sarifRules
    self.options = options()
    self.actions = actions()
  }

  var body: some View {
    VStack {
      EntriesTable(entries: $entries, sarifRules: sarifRules)
      Divider()
      if Options.self != EmptyView.self {
        HStack {
          options
          Spacer()
        }.padding()
      }
      HStack {
        Spacer()
        actions
      }.padding()
    }
  }
}

#Preview {
  @Previewable @State var entries: [IndexEntry] = [
    IndexEntry(
      name: "/user/alex/1", modTime: .now, size: 30_000_000, metadata: ["ALBUM=Wet wet wet"],
      audioDigest: "md5:b1946ac92492d2347c6235b4d2611184",
      pictureDigest: "md5:d41d8cd98f00b204e9800998ecf8427e"),
    IndexEntry(
      name: "/user/alex/2", modTime: .now, size: 30_000_000, metadata: ["ALBUM=We can't dance"],
      audioDigest: "md5:a10edbbb8f28f8e98ee6b649ea2556f4",
      pictureDigest: "md5:d41d8cd98f00b204e9800998ecf8427e"),
  ]

  EntriesView(entries: $entries, sarifRules: nil) {
    Button("Cancel") {
      //
    }.keyboardShortcut(.cancelAction)
    Button("Confirm") {
      //
    }.keyboardShortcut(.defaultAction)
  }
}
