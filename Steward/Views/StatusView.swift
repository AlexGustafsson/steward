import SwiftUI
import SwiftData

enum Progress {
    case known(Float)
    case unknown
}

struct StatusView: View {
    public var progress: Progress
    public var status: String
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack{
            switch progress {
            case let .known(progress):
                ProgressView(value: progress).progressViewStyle(.circular).padding(20)
            default:
                ProgressView().padding(20)
            }
            Text(status)
            }.padding()
                .toolbar {
                    ToolbarItem( placement: .cancellationAction ) {
                        Button( "Cancel" ) { dismiss() }.foregroundStyle(.red).keyboardShortcut(.cancelAction)
                    }
                }.padding(EdgeInsets(top: 20, leading: 40, bottom: 20, trailing: 40))
    
    }
}

#Preview {
    StatusView(progress: .known(0.2), status: "Downloading")
    StatusView(progress: .unknown, status: "Indexing")
}
