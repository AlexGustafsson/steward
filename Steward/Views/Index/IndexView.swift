import SwiftData
import SwiftUI
import os

private let systemLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier!, category: "UI/IndexView")

struct IndexView: View {
  private enum IndexViewState: Equatable {
    case idle
    case indexing(Task<[IndexEntry], Error>)
    case linting(Task<Sarif, Error>)
    case uploading(Task<String, Error>)
    case indexed
    case error(String)
  }

  private enum IndexViewSheet: Hashable, Identifiable {
    case indexProgress
    case uploadProgress
    case lintProgress
    case error(String)
    case saveSuccess
    case uploadSuccess(String)

    var id: Self {
      self
    }
  }

  @State private var state: IndexViewState = .idle
  @State private var sheet: IndexViewSheet? = nil

  @State private var url: URL? = nil
  @State private var entries: [IndexEntry] = []
  @State private var sarifLevel: SarifLevel = .none
  @State private var sarifRules: [String: SarifRule]? = nil

  // TODO: Should essentially be index then viewindex view to allow for export / upload
  // TODO: Similar to upload view (confirm index view?)
  var body: some View {
    Group {
      if self.state == .idle {
        SelectFoldersView(title: "Drag and drop folders to index") { urls in
          let url = urls.first!
          do {
            let task = try StewardTool.index(roots: [url])
            self.state = .indexing(task)
            self.sheet = .indexProgress
            Task {
              do {
                var entries = try await task.value

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
        EntriesView(entries: $entries, sarifRules: sarifRules) {
          Button("Cancel") {
            self.entries = []
            self.state = .idle
            self.sheet = nil
          }.keyboardShortcut(.cancelAction)
          Button("Upload") {
            do {
              let task = try StewardTool.uploadIndex(entries: self.entries)
              self.state = .uploading(task)
              self.sheet = .uploadProgress

              Task {
                do {
                  let id = try await task.value
                  self.state = .indexed
                  self.sheet = .uploadSuccess(id)
                } catch {
                  systemLogger.error("Failed to upload index: \(error, privacy: .public)")
                  self.sheet = .error("Failed to upload index: \(error.localizedDescription)")
                }
              }
            } catch {
              systemLogger.error("Failed to save index: \(error, privacy: .public)")
              self.sheet = .error("Failed to save index: \(error.localizedDescription)")
            }
          }.foregroundStyle(self.sarifLevel.color)
          Button("Export") {
            do {
              try saveIndex(entries: self.entries)
              self.sheet = .saveSuccess
            } catch {
              systemLogger.error("Failed to save index: \(error, privacy: .public)")
              self.sheet = .error("Failed to save index: \(error.localizedDescription)")
            }
          }.keyboardShortcut(.defaultAction)
        }
      }
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
        self.state = .idle
      default:
        break
      }

      self.sheet = nil
    } content: { sheet in
      switch sheet {
      case .indexProgress:
        StatusView(progress: .unknown, status: "Indexing")
      case .uploadProgress:
        StatusView(progress: .unknown, status: "Uploading index")
      case .lintProgress:
        StatusView(progress: .unknown, status: "Linting")
      case .error(let error):
        StatusFailedView(text: error)
      case .saveSuccess:
        StatusCompleteView {
          VStack {
            Text("Index saved successfully").foregroundColor(.blue)
          }
        }
      case .uploadSuccess(let id):
        StatusCompleteView {
          VStack {
            Text("Index upload completed successfully. Your index id:").foregroundColor(.blue)
            Text(id).font(.system(size: 14, design: .monospaced)).textSelection(.enabled)
          }
        }
      }
    }
  }
}

#Preview {
  IndexView()
}
