import SwiftData
import SwiftUI

struct ConfirmEntriesView: View {
  @State public var entries: [Entry]
  public var confirmLabel: String = "Confirm"

  let action: (Bool) -> Void

  init(entries: [Entry], action: @escaping (Bool) -> Void) {
    self.entries = entries
    self.action = action
  }

  init(entries: [Entry], confirmLabel: String, action: @escaping (Bool) -> Void) {
    self.entries = entries
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
  var entries: [Entry] = [
    Entry(
      id: "/user/alexg/1", disc: "1", track: "1", title: "Foo", album: "Wet wet wet",
      artist: "Wet wet wet", composer: nil),
    Entry(
      id: "/user/alexg/2", disc: "1", track: "2", title: "Bar", album: "Wet wet wet",
      artist: "Wet wet wet", composer: nil),
  ]

  ConfirmEntriesView(entries: entries) { confirmed in
    print(confirmed)
  }
}
