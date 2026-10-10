import SwiftData
import SwiftUI

extension Optional where Wrapped == String {
  var unwrapOrEmpty: Wrapped {
    self ?? ""
  }
}

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

  @State private var isDateFilterModalPresented = false
  @State private var startDate: Date?
  @State private var endDate: Date?

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
        TableColumn("File time", value: \.modTime) { entry in
          Text(entry.modTime.formatted())
        }.customizationID("time").defaultVisibility(.hidden)
        TableColumn("Album", value: \.album.unwrapOrEmpty) { entry in
          Text(entry.album ?? "")
        }.customizationID("album")
        TableColumn("Disc #", value: \.disc.unwrapOrEmpty) { entry in
          Text(entry.disc ?? "")
        }.width(50).alignment(.trailing).customizationID("disc")
        TableColumn("Track #", value: \.track.unwrapOrEmpty) { entry in
          Text(entry.track ?? "")
        }.width(50).alignment(.trailing).customizationID("track")
        TableColumn("Artist", value: \.artist.unwrapOrEmpty) { entry in
          Text(entry.artist ?? "")

        }.customizationID("artist")
        TableColumn("Title", value: \.title.unwrapOrEmpty) { entry in
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
        print(sortOrder)
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
        Button {
          self.isDateFilterModalPresented = true
        } label: {
          Label("Time filter", systemImage: "calendar.circle")
        }
      }.sheet(isPresented: $isDateFilterModalPresented) {
        self.isDateFilterModalPresented = false
        self.startDate = nil
        self.endDate = nil
      } content: {
        DateRangePicker(
          startDate: $startDate,
          endDate: $endDate
        ).toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
              self.isDateFilterModalPresented = false
              self.startDate = nil
              self.endDate = nil
            }.keyboardShortcut(.cancelAction)
          }
          ToolbarItem(placement: .primaryAction) {
            Button("Filter") {
              self.isDateFilterModalPresented = false

              // NOTE: As we won't filter without at least one date selected,
              // in practice the start date will never be empty
              let startDate = Calendar.current.startOfDay(for: self.startDate ?? Date.distantPast)
              let endDate = Calendar.current.endOfDay(for: self.endDate ?? Date.distantFuture)

              self.entries.removeAll(where: {
                $0.modTime < startDate || $0.modTime > endDate
              })

              self.startDate = nil
              self.endDate = nil
            }.keyboardShortcut(.defaultAction).disabled(
              self.startDate == nil && self.endDate == nil)
          }
        }.padding(EdgeInsets(top: 20, leading: 40, bottom: 20, trailing: 40))

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
