import SwiftData
import SwiftUI

struct LogTable: View {
  @State public var logs: [LogEntry]

  @State private var sortOrder = [KeyPathComparator(\LogEntry.time)]
    @State private var columnCustomization: TableColumnCustomization<LogEntry> = .init()

  var body: some View {
    VStack {
      Table(
        of: LogEntry.self, sortOrder: $sortOrder,
        columnCustomization: $columnCustomization
      ) {
        TableColumn("Date") { entry in
            Text(entry.time.formatted(date: .numeric, time: .complete))
        }.width(200).customizationID("date")
          TableColumn("Level") { entry in
              Text(entry.level)
          }.width(50).customizationID("level")
          TableColumn("Message") { entry in
              Text(entry.msg)
          }.customizationID("message")
          TableColumn("Error") { entry in
              Text(entry.error ?? "")
          }.customizationID("error")
          
          TableColumn("Index name") { entry in
              Text(entry.additionalProperties["indexName"]?.string ?? "")
          }.customizationID("indexName").defaultVisibility(.hidden)
          TableColumn("Audio digest") { entry in
              Text(entry.additionalProperties["audioDigest"]?.string ?? "")
          }.customizationID("audioDigest").defaultVisibility(.hidden)
          TableColumn("Failures") { entry in
              Text(entry.additionalProperties["failures"]?.string ?? "")
          }.customizationID("failures").defaultVisibility(.hidden)
          TableColumn("Successes") { entry in
              Text(entry.additionalProperties["successes"]?.string ?? "")
          }.customizationID("successes").defaultVisibility(.hidden)
          TableColumn("Uploaded bytes") { entry in
              Text(entry.additionalProperties["uploadedBytes"]?.string ?? "")
          }.customizationID("uploadedBytes").defaultVisibility(.hidden)
          TableColumn("Downloaded bytes") { entry in
              Text(entry.additionalProperties["downloadedBytes"]?.string ?? "")
          }.customizationID("downloadedBytes").defaultVisibility(.hidden)
      } rows: {
          ForEach(logs) { entry in
              TableRow(entry)
          }
      }.onChange(of: sortOrder) { _, sortOrder in
          logs.sort(using: sortOrder)
      }
    }
  }
}

#Preview {
    let logs = [
        LogEntry(id: 0, time: Date.now, level: "DEBUG", msg: "Hello World", error: "Error", additionalProperties: ["failures": .int(1)]),
    ]

  LogTable(logs: logs)
}
