import SwiftData
import SwiftUI
import os

private let systemLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier!, category: "UI/UploadView")

struct UploadView: View {
  private enum UploadViewState: Equatable {
    case idle
    case indexing(Task<[IndexEntry], Error>)
    case linting(Task<Sarif, Error>)
    case indexed
    case uploading(Task<String, Error>)
    case success(String)
  }

  private enum UploadViewSheet: Hashable, Identifiable {
    case indexProgress
    case lintProgress
    case uploadProgress
    case success(String)
    case error(String)

    var id: Self {
      self
    }
  }

  @State private var force = false
  @State private var showForceHelp = false

  @State private var state: UploadViewState = .idle
  @State private var sheet: UploadViewSheet? = nil

  @State private var url: URL? = nil
  @State private var entries: [IndexEntry] = []
  @State private var sarifLevel: SarifLevel = .none
  @State private var sarifRules: [String: SarifRule]? = nil
  @State private var uploadProgress: StewardTool.UploadProgress? = nil

  var body: some View {
    if self.state == .idle {
      SelectFoldersView(title: "Drag and drop folder to upload", multi: false) { urls in
        let url = urls.first!

        do {
          let task = try StewardTool.index(roots: [url])
          self.state = .indexing(task)
          self.sheet = .indexProgress
          Task {
            do {
              var entries = try await task.value
              self.url = url

              do {
                let task = try StewardTool.lint(entries: entries)
                self.state = .linting(task)
                self.sheet = .lintProgress

                let sarif = try await task.value
                self.sarifRules = sarif.populate(entries: &entries, level: &self.sarifLevel)
                self.entries = entries
                self.state = .indexed
                self.sheet = nil
              } catch {
                systemLogger.error("Failed to lint: \(error, privacy: .public)")
                self.sheet = .error("Failed to lint: \(error.localizedDescription)")
              }
            } catch {
              systemLogger.error("Failed to index: \(error, privacy: .public)")
              self.sheet = .error("Failed to index: \(error.localizedDescription)")
            }
          }
        } catch {
          systemLogger.error("Failed to index: \(error, privacy: .public)")
          self.sheet = .error("Failed to index: \(error.localizedDescription)")
        }
      }
    } else {
      EntriesView(
        entries: $entries, sarifRules: sarifRules
      ) {
        Toggle(isOn: $force) {
          Text("Force")
        }
        .toggleStyle(.checkbox)
        .foregroundStyle(.red)
        Button(action: { showForceHelp.toggle() }) {
          Image(systemName: "info.circle").foregroundStyle(.secondary)
        }.popover(isPresented: $showForceHelp) {
          Text("Overwrite remote or local files if they don't already match").padding()
        }.buttonStyle(PlainButtonStyle())
      } actions: {
        Button("Cancel") {
          self.url = nil
          self.entries = []
          self.state = .idle
          self.sheet = nil
        }.keyboardShortcut(.cancelAction)
        Button("Upload") {
          do {
            self.uploadProgress = nil
            let task = try StewardTool.upload(
              root: self.url!, entries: self.entries, force: force
            ) { progress in
              self.uploadProgress = progress
            }
            self.state = .uploading(task)
            self.sheet = .uploadProgress
            Task {
              do {
                let id = try await task.value
                self.state = .success(id)
                self.sheet = .success(id)
              } catch {
                systemLogger.error("Failed to upload: \(error, privacy: .public)")
                self.sheet = .error("Failed to upload: \(error.localizedDescription)")
              }
            }
          } catch {
            systemLogger.error("Failed to upload: \(error, privacy: .public)")
            self.sheet = .error("Failed to upload: \(error.localizedDescription)")
          }
        }.foregroundStyle(self.force ? .red : self.sarifLevel.color)
      }.sheet(item: $sheet) {
        switch state {
        case .indexing(let task):
          task.cancel()
          self.state = .idle
        case .linting(let task):
          task.cancel()
          self.state = .idle
        case .uploading(let task):
          task.cancel()
          self.state = .indexed
        case .success:
          self.state = .idle
          self.entries = []
          self.url = nil
        default:
          break
        }
        self.sheet = nil
      } content: { sheet in
        switch sheet {
        case .indexProgress:
          StatusView(progress: .unknown, status: "Indexing")
        case .lintProgress:
          StatusView(progress: .unknown, status: "Linting")
        case .uploadProgress:
          StatusView(
            progress: .known(
              self.uploadProgress?.successes ?? 0, self.uploadProgress?.failures ?? 0,
              self.uploadProgress?.total ?? 0
            ),
            status: "Uploading")
        case .success(let id):
          StatusCompleteView {
            VStack {
              Text("Upload completed successfully. Your index id:").foregroundColor(.blue)
              Text(id).font(.system(size: 14, design: .monospaced)).textSelection(.enabled)
            }
          }
        case .error(let error):
          StatusFailedView(text: error)
        }
      }
    }
  }
}

#Preview {
  UploadView()
}
