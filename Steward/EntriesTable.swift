import SwiftUI
import SwiftData

struct Entry: Identifiable {
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
    @State public var entries: [Entry]
    
    @State private var sortOrder = [KeyPathComparator(\Entry.id)]
    @State private var columnCustomization: TableColumnCustomization<Entry> = .init()
    
    var body: some View {
        VStack{
            Table(entries, sortOrder: $sortOrder, columnCustomization: $columnCustomization) {
                TableColumn("Disc #") { entry in
                    Text(entry.disc ?? "")
                }.customizationID("disc")
                TableColumn("Track #") { entry in
                    Text(entry.track ?? "")
                }.customizationID("track")
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
            }.onChange(of: sortOrder) { _, sortOrder in
                entries.sort(using: sortOrder)
            }
        }
    }
}

#Preview {
    var entries: [Entry] = [
        Entry(id: "/user/alexg/1", disc: "1", track: "1", title: "Foo", album: "Wet wet wet", artist: "Wet wet wet", composer: nil),
        Entry(id: "/user/alexg/2", disc: "1", track: "2", title: "Bar", album: "Wet wet wet", artist: "Wet wet wet", composer: nil),
    ];
    
    EntriesTable(entries: entries)
}
