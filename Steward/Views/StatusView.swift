import SwiftData
import SwiftUI

enum Progress {
  case known(Float)
  case unknown
}

struct StatusView: View {
    public var progress: Progress
    public var status: String
    @State public var logs: [LogEntry]

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack {
      LogTable(logs: logs).frame(width: 500, height: 400)
      Divider()
      switch progress {
      case .known(let progress):
        ProgressView(value: progress).progressViewStyle(.circular).padding(20)
      default:
        ProgressView().padding(20)
      }
    }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }.foregroundStyle(.red).keyboardShortcut(.cancelAction)
        }
      }.padding(EdgeInsets(top: 20, leading: 40, bottom: 20, trailing: 40))

  }
}

#Preview {
    let logs = [
        LogEntry(id: 0, time: Date.now, level: "DEBUG", msg: "Hello World"),
    ]
    
    StatusView(progress: .known(0.2), status: "Downloading", logs: logs)
}
