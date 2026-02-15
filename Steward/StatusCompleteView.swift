import SwiftUI
import SwiftData

struct StatusCompleteView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack{
            Image(systemName: "party.popper.fill").symbolRenderingMode(.hierarchical).font(.largeTitle).foregroundStyle(.blue.gradient).symbolEffect(.wiggle, options: .nonRepeating)
            Text("Success").foregroundStyle(.blue)
            }.padding()
                .toolbar {
                    ToolbarItem( placement: .cancellationAction ) {
                        Button( "Dismiss" ) { dismiss() }.keyboardShortcut(.defaultAction)
                    }
                }.padding(EdgeInsets(top: 20, leading: 40, bottom: 20, trailing: 40))
    }
}

#Preview {
    StatusCompleteView()
}
