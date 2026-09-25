import SwiftData
import SwiftUI

struct SarifLevelImage: View {
  let level: SarifLevel?

  var body: some View {
    if let level = level {
      Image(systemName: level.systemName).foregroundStyle(level.color)
    } else {
      EmptyView()
    }
  }
}

struct EntriesTable: View {
  @Binding public var entries: [IndexEntry]
  public var sarifRules: [String: SarifRule]?

  @State private var filteredEntries: [IndexEntry] = []

  @State private var selection: Set<IndexEntry.ID> = []
  @State private var sortOrder = [KeyPathComparator(\IndexEntry.sortKey)]
  @State private var columnCustomization: TableColumnCustomization<IndexEntry> = .init()

  @State private var isInspectorPresented = true
  @State private var searchText = ""

  func delete(_ id: IndexEntry.ID) {
    if let index = entries.firstIndex(where: { $0.id == id }) {
      entries.remove(at: index)
    }
  }

  func filterEntries(
    entries: [IndexEntry],
    searchText: String,
  ) -> [IndexEntry] {
    if searchText.isEmpty {
      return entries
    }

    return entries.filter { entry in
      let query = searchText.lowercased()
      let album = entry.album?.lowercased() ?? ""
      let artist = entry.artist?.lowercased() ?? ""
      let title = entry.title?.lowercased() ?? ""

      return album.contains(query) || artist.contains(query) || title.contains(query)
    }
  }

  var body: some View {
    VStack {
      Table(
        of: IndexEntry.self, selection: $selection, sortOrder: $sortOrder,
        columnCustomization: $columnCustomization
      ) {
        if sarifRules != nil {
          TableColumn("Checks") { entry in
            SarifLevelImage(level: entry.sarif?.first?.level)
          }.width(50).alignment(.center).customizationID("checks")
        }
        TableColumn("Album") { entry in
          Text(entry.album ?? "")
        }.customizationID("album")
        TableColumn("Disc #") { entry in
          Text(entry.disc ?? "")
        }.width(50).alignment(.trailing).customizationID("disc")
        TableColumn("Track #") { entry in
          Text(entry.track ?? "")
        }.width(50).alignment(.trailing).customizationID("track")
        TableColumn("Artist") { entry in
          Text(entry.artist ?? "")

        }.customizationID("artist")
        TableColumn("Title") { entry in
          Text(entry.title ?? "")
        }.customizationID("title")
      } rows: {
        ForEach(filteredEntries) { entry in
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
              }.keyboardShortcut(.delete, modifiers: [])
            }
        }
      }
      .onChange(of: sortOrder) { _, sortOrder in
        entries.sort(using: sortOrder)
      }
      .onDeleteCommand {
        for entry in selection {
          delete(entry)
        }
        selection.removeAll()
      }.inspector(isPresented: $isInspectorPresented) {
        IndexEntryInspectorForm(
          entries: entries, selection: selection, sarifRules: sarifRules
        )
        .inspectorColumnWidth(
          min: 300, ideal: 400, max: 500
        ).toolbar {
          Button {
            isInspectorPresented.toggle()
          } label: {
            Label("Toggle Inspector", systemImage: "info.circle")
          }
        }
      }
      .searchable(text: $searchText)
      .onChange(of: searchText) {
        self.filteredEntries = filterEntries(entries: self.entries, searchText: self.searchText)
      }.onChange(of: entries) {
        self.filteredEntries = filterEntries(entries: self.entries, searchText: self.searchText)
      }.toolbar {
        Button {
          // TODO
        } label: {
          Label("Undo", systemImage: "arrow.uturn.backward.circle")
        }
      }
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

  EntriesTable(entries: $entries)
}
