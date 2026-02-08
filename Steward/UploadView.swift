import SwiftUI
import SwiftData

struct UploadView: View {
    @Binding var inProgress: Bool
   
    var body: some View {
        ZStack {
            VStack {
                Image(systemName: "arrow.up.folder").font(.largeTitle).foregroundStyle(.blue)
                Text("Drag and drop folders to upload").font(.largeTitle)
                Button("Select folders") {
                    
                }.foregroundStyle(.blue)
            }
            Rectangle().stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
        }.padding(EdgeInsets(top: 20, leading: 30, bottom: 30, trailing: 40))
    }
}

#Preview {
    @Previewable @State var inProgress = false
    IndexView(inProgress: $inProgress)
}
