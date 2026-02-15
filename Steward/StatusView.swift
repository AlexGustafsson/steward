import SwiftUI
import SwiftData

struct StatusView: View {
    public var progress: Float
    public var status: String
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack{
            ProgressView(value: progress).progressViewStyle(.circular).padding(20)
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
    StatusView(progress: 0.2, status: "Downloading")
}
