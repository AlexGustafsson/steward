import SwiftUI
import SwiftData

struct IndexView: View {
    @State private var showIndexProgressSheet: Bool = false
    
    var body: some View {
            SelectFoldersView(title: "Drag and drop folders to index")  { urls in
                let savePanel = NSSavePanel()
                savePanel.canCreateDirectories = true
                savePanel.showsContentTypes = true
                savePanel.showsTagField = false
                savePanel.nameFieldStringValue = "index"
                savePanel.allowedContentTypes = [.json]
                savePanel.begin { (result) in
                    if result == .OK {
                        showIndexProgressSheet = true
                        
                        let helperURL = Bundle.main.bundleURL
                            .appendingPathComponent("Contents/MacOS/StewardTool")

                        let process = Process()
                        process.executableURL = helperURL
                        process.arguments = ["--help"]
                        
                        let pipe = Pipe()
                        process.standardOutput = pipe
                        process.standardError = pipe
                        
                        do {
                            try process.run()
                            process.waitUntilExit()
                            
                            let data = pipe.fileHandleForReading.readDataToEndOfFile()
                                if let output = String(data: data, encoding: .utf8) {
                                    print(output)
                                }
                        } catch {
                            print("Failed \(error)")
                        }
                    }
                }
            }.sheet(isPresented: $showIndexProgressSheet) {
                // TODO
                print("Dismissed")
            } content: {
                StatusView(progress: .unknown, status: "Indexing")
            }
    }
}

#Preview {
    IndexView()
}
