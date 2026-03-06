import SwiftData
import SwiftUI

struct ConfirmEntriesView: View {
  @Binding public var entries: [IndexEntry]
  public var confirmLabel: String = "Confirm"
      
  let action: (Bool, Bool) -> Void
    
    @State private var force  = false
    @State private var showForceHelp = false

    init(entries: Binding<[IndexEntry]>, action: @escaping (Bool, Bool) -> Void) {
    self._entries = entries
    self.action = action
  }

  init(entries: Binding<[IndexEntry]>, confirmLabel: String, action: @escaping (Bool, Bool) -> Void) {
    self._entries = entries
    self.confirmLabel = confirmLabel
    self.action = action
  }

  var body: some View {
    VStack {
      EntriesTable(entries: $entries)
      Divider()
        HStack {
            Toggle(isOn: $force) {
                Text("Force")
            }
            .toggleStyle(.checkbox)
            .foregroundStyle(.red)
            Button(action: { showForceHelp.toggle() }) {
                Image(systemName: "info.circle").foregroundStyle(.secondary)
            }.popover(isPresented: $showForceHelp) {
                Text("Overwrite remote or local files if they don't already match").padding()
            }.buttonStyle(PlainButtonStyle())
            Spacer()
        }.padding()
      HStack {
        Spacer()
        Button("Cancel") {
            self.action(false, self.force)
        }
        Button(confirmLabel) {
            self.action(true, self.force)
        }.foregroundStyle(self.force ? .red : .blue)
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

  ConfirmEntriesView(entries: $entries) { confirmed, force in
    print(confirmed)
  }
}
