import SwiftData
import SwiftUI

struct EntriesTable: View {
  @Binding public var entries: [IndexEntry]

  @State private var selection: Set<IndexEntry.ID> = []
  @State private var sortOrder = [KeyPathComparator(\IndexEntry.id)]
  @State private var columnCustomization: TableColumnCustomization<IndexEntry> = .init()

  func delete(_ id: IndexEntry.ID) {
    if let index = entries.firstIndex(where: { $0.id == id }) {
      entries.remove(at: index)
    }
  }

  var body: some View {
    VStack {
      Table(
        of: IndexEntry.self, selection: $selection, sortOrder: $sortOrder,
        columnCustomization: $columnCustomization
      ) {
        TableColumn("Disc #") { entry in
          Text(entry.disc ?? "")
        }.width(50).customizationID("disc")
        TableColumn("Track #") { entry in
          Text(entry.track ?? "")
        }.width(50).customizationID("track")
        TableColumn("Title") { entry in
          Text(entry.title ?? "")
        }.customizationID("title")
        TableColumn("Album") { entry in
          Text(entry.album ?? "")
        }.customizationID("album")
        TableColumn("Artist") { entry in
          Text(entry.artist ?? "")
        }.customizationID("artist")
        TableColumn("Composer") { entry in
          Text(entry.composer ?? "")
        }.customizationID("composer")
      } rows: {
        ForEach(entries) { entry in
          TableRow(entry)
            .contextMenu {
              Button("Delete", role: .destructive) {
                if selection.isEmpty {
                  delete(entry.id)
                } else {
                  for entry in selection {
                    delete(entry)
                  }
                  selection.removeAll()
                }
              }
            }
        }
      }.onChange(of: sortOrder) { _, sortOrder in
        entries.sort(using: sortOrder)
      }
    }
  }
}

#Preview {
  @Previewable @State var entries: [IndexEntry] = [
    IndexEntry(name: "/user/alex/1", modTime: .now, size: 30000000, metadata: ["ALBUM=Wet wet wet"], audioDigest: "md5:b1946ac92492d2347c6235b4d2611184", pictureDigest: "md5:d41d8cd98f00b204e9800998ecf8427e"),
    IndexEntry(name: "/user/alex/2", modTime: .now, size: 30000000, metadata: ["ALBUM=We can't dance"], audioDigest: "md5:a10edbbb8f28f8e98ee6b649ea2556f4", pictureDigest: "md5:d41d8cd98f00b204e9800998ecf8427e")
  ]

  EntriesTable(entries: $entries)
}
