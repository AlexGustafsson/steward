import Foundation

extension Pipe {
  func readLines(onLine: @escaping (Data) throws -> Void) async throws {
    try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.global().async {
        do {
          var buffer = Data()
          while true {
            let chunk = self.fileHandleForReading.availableData
            if chunk.isEmpty {
              break
            }

            buffer.append(chunk)
            while let linebreak = buffer.firstIndex(of: UInt8(ascii: "\n")) {
              let line = Data(buffer[buffer.startIndex..<linebreak])
              buffer = Data(buffer[buffer.index(after: linebreak)...])
              try onLine(line)
            }
          }
          continuation.resume()
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }
}
