import SwiftData
import SwiftUI

struct ConfirmEntriesView: View {
  @Binding public var entries: [IndexEntry]
  public var confirmLabel: String = "Confirm"

  let action: (Bool) -> Void

  init(entries: Binding<[IndexEntry]>, action: @escaping (Bool) -> Void) {
    self._entries = entries
    self.action = action
  }

  init(entries: Binding<[IndexEntry]>, confirmLabel: String, action: @escaping (Bool) -> Void) {
    self._entries = entries
    self.confirmLabel = confirmLabel
    self.action = action
  }

  var body: some View {
    VStack {
      EntriesTable(entries: $entries)
      HStack {
        Spacer()
        Button("Cancel") {
          self.action(false)
        }
        Button(confirmLabel) {
          self.action(true)
        }.foregroundStyle(.blue)
      }.padding()
    }
  }
}

#Preview {
    @Previewable @State var entries: [IndexEntry] = [
    IndexEntry(name: "/user/alex/1", modTime: .now, size: 30000000, metadata: ["ALBUM=Wet wet wet"], audioDigest: "md5:b1946ac92492d2347c6235b4d2611184", pictureDigest: "md5:d41d8cd98f00b204e9800998ecf8427e"),
    IndexEntry(name: "/user/alex/2", modTime: .now, size: 30000000, metadata: ["ALBUM=We can't dance"], audioDigest: "md5:a10edbbb8f28f8e98ee6b649ea2556f4", pictureDigest: "md5:d41d8cd98f00b204e9800998ecf8427e")
  ]

  ConfirmEntriesView(entries: $entries) { confirmed in
    print(confirmed)
  }
}
