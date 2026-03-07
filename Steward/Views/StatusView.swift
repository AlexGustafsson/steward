import SwiftData
import SwiftUI

enum Progress {
  case known(UInt64, UInt64)
  case unknown
}

struct StatusView: View {
  public var progress: Progress
  public var status: String

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack {
      switch progress {
      case .known(let current, let total):
        ProgressView(value: total == 0 ? 0.0 : Double(current) / Double(total)).progressViewStyle(
          .circular
        ).padding(20)
        Text("\(current)/\(total)").foregroundStyle(.secondary)
      case .unknown:
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
  StatusView(progress: .known(1, 2), status: "Downloading")
}
