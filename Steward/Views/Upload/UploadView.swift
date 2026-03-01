import SwiftData
import SwiftUI

struct UploadView: View {
    @State private var url: URL? = nil
  @State private var indexTask: Task<[IndexEntry], Error>? = nil
  @State private var indexEntries: [IndexEntry] = []
  @State private var showIndexProgressSheet: Bool = false

  @State private var uploadTask: Task<Void, Error>? = nil
  @State private var showUploadProgressSheet: Bool = false
  @State private var showCompletedSheet: Bool = false
  @State private var showFailedSheet: Bool = false

  @State private var uploadProgress: Float = 0.0
  @State private var uploadStatus: String = ""

    var body: some View {
        if indexEntries.count == 0 {
            SelectFoldersView(title: "Drag and drop folder to upload", multi: false) { urls in
                let url = urls.first!
                self.showIndexProgressSheet = true

                do {
                    self.indexTask = try index(roots: [url])
                    Task {
                        do {
                            self.url = url
                            self.indexEntries = try await self.indexTask!.value
                        } catch {
                            print(error)
                        }
                        showIndexProgressSheet = false
                        self.indexTask = nil
                    }
                } catch {
                    print(error)
                    return
                }
        }.sheet(isPresented: $showIndexProgressSheet) {
            self.indexTask?.cancel()
            self.indexTask = nil
        } content: {
            StatusView(progress: .unknown, status: "Indexing")
        }.sheet(isPresented: $showCompletedSheet) {
            // TODO
        } content: {
            StatusCompleteView()
        }
    } else {
      ConfirmEntriesView(
        entries: $indexEntries, confirmLabel: "Upload",
        action: { confirmed in
          if confirmed {
            self.showUploadProgressSheet = true
              
              do {
                  // TODO: Progress reporting
                  self.uploadTask = try upload(root: url!, entries: indexEntries)
                  Task {
                      do {
                          let _ = try await self.uploadTask?.value
                          self.showCompletedSheet = true
                          self.indexEntries = []
                      } catch {
                          self.showFailedSheet = true
                          print(error)
                      }
                      self.uploadTask = nil
                      self.showUploadProgressSheet = false
                      withAnimation {
                        self.uploadProgress = 1.0
                      }
                  }
              } catch {
                  print(error)
                  return
              }
          } else {
            self.indexEntries = []
            self.showUploadProgressSheet = false
          }
        }
      ).sheet(isPresented: $showUploadProgressSheet) {
          self.uploadTask?.cancel()
          self.uploadTask = nil
      } content: {
        StatusView(progress: .known(self.uploadProgress), status: "Uploading")
      }.sheet(isPresented: $showFailedSheet) {
          self.showFailedSheet = false
      } content: {
        Text("Failed!")
      }
    }
  }
}

#Preview {
  UploadView()
}
