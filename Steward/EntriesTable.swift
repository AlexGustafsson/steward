import SwiftUI
import SwiftData

struct Entry: Identifiable, Equatable {
    // The file's path
    var id: String
    var disc: String?
    var track: String?
    var title: String?
    var album: String?
    var artist: String?
    var composer: String?
}

struct EntriesTable: View {
    @Binding public var entries: [Entry]
    
    @State private var selection: Set<Entry.ID> = []
    @State private var sortOrder = [KeyPathComparator(\Entry.id)]
    @State private var columnCustomization: TableColumnCustomization<Entry> = .init()
    
    func delete(_ id: Entry.ID) {
        if let index = entries.firstIndex(where: {$0.id == id}) {
            entries.remove(at: index)
        }
    }
    
    var body: some View {
        VStack{
            Table(of: Entry.self, selection: $selection, sortOrder: $sortOrder, columnCustomization: $columnCustomization) {
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
    @Previewable @State var entries: [Entry] = [
        Entry(id: "/user/alexg/1", disc: "1", track: "1", title: "Foo", album: "Wet wet wet", artist: "Wet wet wet", composer: nil),
        Entry(id: "/user/alexg/2", disc: "1", track: "2", title: "Bar", album: "Wet wet wet", artist: "Wet wet wet", composer: nil),
    ];
    
    EntriesTable(entries: $entries)
}
