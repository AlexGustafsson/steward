import Foundation

struct Index {
  public var raw: String
}

enum IndexerStatus {
  case idle
  case running
  case succeeded(Index)
  case failed(Error)
}

@MainActor
class Indexer: ObservableObject {
  @Published var status: IndexerStatus = .idle

  private var task: Task<Void, Never>?

  func index(roots: [URL], outputPath: URL, _ callback: @escaping (Index) -> Void) {
    self.cancel()

    task = Task {
      FileManager.default.createFile(atPath: outputPath.path, contents: nil)

      guard let fileHandle = try? FileHandle(forWritingTo: outputPath) else {
        print("Bad file handle")
        return
      }

      let toolURL = Bundle.main.bundleURL
        .appendingPathComponent("Contents/MacOS/StewardTool")

      let process = Process()
      process.executableURL = toolURL
      process.arguments = ["index"] + roots.map({ x in x.path(percentEncoded: false) })

      let stderr = Pipe()
      process.standardOutput = fileHandle
      process.standardError = stderr

      do {
        await MainActor.run {
          self.status = .running
        }

        try process.run()
        try fileHandle.close()
        process.waitUntilExit()

        let data = stderr.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!
        print("Done \(output)")
        await MainActor.run {
          let index = Index(raw: output)
          self.status = .succeeded(index)
          callback(index)
        }
      } catch {
        print("Failed to run \(error)")
        await MainActor.run {
          self.status = .failed(error)
        }
      }
    }
  }

  func cancel() {
    task?.cancel()
  }
}
