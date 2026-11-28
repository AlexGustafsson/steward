import SwiftData
import SwiftUI

struct LogView: View {
  public let entry: LogEntry

  @State private var isExpanded = false

  @ScaledMetric(relativeTo: .caption)
  private var timestampWidth: CGFloat = 110

  @ScaledMetric(relativeTo: .caption)
  private var levelWidth: CGFloat = 55

  let dateFormat = Date.FormatStyle()
    .hour(.twoDigits(amPM: .wide))
    .minute(.twoDigits)
    .second(.twoDigits)

  init(_ entry: LogEntry) {
    self.entry = entry
    self._isExpanded = State(initialValue: entry.error != nil)
  }

  var foregroundStyle: some ShapeStyle {
    switch self.entry.level {
    case "DEBUG":
      Color.secondary
    case "INFO":
      Color.primary
    case "WARN":
      Color.orange
    case "ERROR":
      Color.red
    default:
      Color.primary
    }
  }

  var body: some View {
    DisclosureGroup(isExpanded: self.$isExpanded) {
      VStack {
        HStack {
          Text("msg")
            .foregroundStyle(.secondary)
            .frame(minWidth: 100, alignment: .leading)

          Text(self.entry.msg).frame(maxWidth: .infinity, alignment: .leading)
        }
        ForEach(self.entry.additionalProperties.keys.sorted(), id: \.self) { key in
          if let value = self.entry.additionalProperties[key] {
            HStack {
              Text(key)
                .foregroundStyle(.secondary)
                .frame(minWidth: 100, alignment: .leading)

              Text(value.string)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        }
      }.background(.thinMaterial)
    } label: {
      HStack(alignment: .top) {
        Text(self.entry.time.formatted(dateFormat)).frame(width: 60, alignment: .leading)
        Text(self.entry.level).frame(width: 40, alignment: .leading)
        Text(self.entry.msg).frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
      }.foregroundStyle(self.foregroundStyle)
    }.font(.system(.caption, design: .monospaced)).onTapGesture(perform: {
      // NOTE: Normally the user needs to click on a small chevron, let them
      // instead click on the line to toggle its visibility
      withAnimation {
        self.isExpanded = !self.isExpanded
      }
    })
  }
}

struct LogsView: View {
  @Binding public var entries: [LogEntry]

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(entries.enumerated(), id: \.offset) { _, entry in
          LogView(entry)
        }
      }
      .padding()
    }
  }
}

#Preview {
  @Previewable @State var entries: [LogEntry] = [
    LogEntry(
      time: .now, level: "DEBUG",
      msg:
        "Performing some very detailed and extraordinarily long task that will contain multiple lines",
      additionalProperties: ["key": .string("Value")]),
    LogEntry(
      time: .now, level: "INFO", msg: "Performing action",
      additionalProperties: ["key": .string("Value")]),
    LogEntry(
      time: .now, level: "WARN", msg: "Performing action",
      additionalProperties: ["key": .string("Value")]),
    LogEntry(
      time: .now, level: "ERROR", msg: "Performing action", error: "Failed to perform action",
      additionalProperties: ["key": .string("Value"), "error": .string("Failed to perform action")]),
  ]

  LogsView(entries: $entries)
    .padding(20)
}
