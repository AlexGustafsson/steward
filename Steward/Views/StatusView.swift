import SwiftData
import SwiftUI

enum Progress {
  case known(UInt64, UInt64, UInt64)
  case unknown
}

struct StatusView: View {
  public var progress: Progress
  public var status: String

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack {
      switch progress {
      case .known(let success, let fail, let total):
        ZStack {
          Circle()
            .trim(
              from: Double(fail) / Double(total),
              to: total > 0 ? Double(success + fail) / Double(total) : 0.0
            )
            .rotation(.degrees(-90))
            .stroke(.tint, style: StrokeStyle(lineWidth: 5, lineCap: .butt))
            .frame(width: 26, height: 26)
          Circle()
            .trim(from: 0.0, to: total > 0 ? Double(fail) / Double(total) : 0.0)
            .rotation(.degrees(-90))
            .stroke(.tint, style: StrokeStyle(lineWidth: 5, lineCap: .butt))
            .frame(width: 26, height: 26).tint(.red)
        }.padding(20)
        Text("\(status) \(success+fail)/\(total)").foregroundStyle(.secondary)
      case .unknown:
        ProgressView().padding(20)
        Text(status)
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
  StatusView(progress: .known(1, 1, 2), status: "Downloading")
}
