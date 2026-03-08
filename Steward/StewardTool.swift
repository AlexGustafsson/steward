import Foundation
import os

private let systemLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier!, category: "Steward")

class StewardTool {
  private enum File {
    case fileHandle(FileHandle)
    case pipe(Pipe)
  }

  private protocol Stdin {
    var file: File { get }
    func wait() async throws
  }

  private struct Encoder<T: Encodable>: Stdin {
    private let pipe: Pipe
    private let task: Task<Void, Swift.Error>

    init(entries: [T]) {
      let pipe = Pipe()

      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601

      self.pipe = pipe
      self.task = Task {
        for entry in entries {
          let line = try encoder.encode(entry)
          try pipe.fileHandleForWriting.write(contentsOf: line)
          try pipe.fileHandleForWriting.write(contentsOf: "\n".data(using: .utf8)!)
        }
        try? pipe.fileHandleForWriting.close()
      }
    }

    var file: File {
      return .pipe(self.pipe)
    }

    func wait() async throws {
      let _ = try await self.task.value
    }
  }

  private protocol Stdout {
    var file: File { get }
    func wait() async throws
  }

  private struct Decoder<T: Decodable>: Stdout {
    private let pipe: Pipe
    private let task: Task<[T], Swift.Error>

    init() {
      let pipe = Pipe()

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601

      self.pipe = pipe
      self.task = Task {
        var entries = [T]()
        for try await line in pipe.fileHandleForReading.bytes.lines {
          let line = line.data(using: .utf8)!
          let entry = try decoder.decode(T.self, from: line)
          entries.append(entry)
        }
        return entries
      }
    }

    var file: File {
      return .pipe(self.pipe)
    }

    func wait() async throws {
      let _ = try await self.task.value
    }

    func values() async throws -> [T] {
      return try await self.task.value
    }
  }

  private struct FileWriter: Stdout {
    private let fileHandle: FileHandle

    init(outputPath: URL) throws {
      FileManager.default.createFile(atPath: outputPath.path, contents: nil)

      self.fileHandle = try FileHandle(forWritingTo: outputPath)
    }

    var file: File {
      return .fileHandle(self.fileHandle)
    }

    func wait() async throws {
      // Do nothing
    }
  }

  private protocol Stderr {
    var file: File { get }
    func wait() async throws
  }

  public struct DownloadProgress: Hashable {
    public var failures: UInt64
    public var successes: UInt64
    public var downloadedBytes: UInt64
    public var processedBytes: UInt64
    public var totalEntries: UInt64
    public var totalBytes: UInt64
    public var processedEntries: UInt64

    init?(fromEntry entry: LogEntry) {
      if case .number(let failures) = entry.additionalProperties["failures"] {
        self.failures = UInt64(failures)
      } else {
        return nil
      }

      if case .number(let successes) = entry.additionalProperties["successes"] {
        self.successes = UInt64(successes)
      } else {
        return nil
      }

      if case .number(let downloadedBytes) = entry.additionalProperties["downloadedBytes"] {
        self.downloadedBytes = UInt64(downloadedBytes)
      } else {
        return nil
      }

      if case .number(let processedBytes) = entry.additionalProperties["processedBytes"] {
        self.processedBytes = UInt64(processedBytes)
      } else {
        return nil
      }

      if case .number(let totalEntries) = entry.additionalProperties["totalEntries"] {
        self.totalEntries = UInt64(totalEntries)
      } else {
        return nil
      }

      if case .number(let totalBytes) = entry.additionalProperties["totalBytes"] {
        self.totalBytes = UInt64(totalBytes)
      } else {
        return nil
      }

      if case .number(let processedEntries) = entry.additionalProperties["processedEntries"] {
        self.processedEntries = UInt64(processedEntries)
      } else {
        return nil
      }
    }
  }

  public struct UploadProgress {
    public var failures: UInt64
    public var successes: UInt64
    public var uploadedBytes: UInt64
    public var processedBytes: UInt64
    public var totalEntries: UInt64
    public var totalBytes: UInt64
    public var processedEntries: UInt64

    init?(fromEntry entry: LogEntry) {
      if case .number(let failures) = entry.additionalProperties["failures"] {
        self.failures = UInt64(failures)
      } else {
        return nil
      }

      if case .number(let successes) = entry.additionalProperties["successes"] {
        self.successes = UInt64(successes)
      } else {
        return nil
      }

      if case .number(let uploadedBytes) = entry.additionalProperties["uploadedBytes"] {
        self.uploadedBytes = UInt64(uploadedBytes)
      } else {
        return nil
      }

      if case .number(let processedBytes) = entry.additionalProperties["processedBytes"] {
        self.processedBytes = UInt64(processedBytes)
      } else {
        return nil
      }

      if case .number(let totalEntries) = entry.additionalProperties["totalEntries"] {
        self.totalEntries = UInt64(totalEntries)
      } else {
        return nil
      }

      if case .number(let totalBytes) = entry.additionalProperties["totalBytes"] {
        self.totalBytes = UInt64(totalBytes)
      } else {
        return nil
      }

      if case .number(let processedEntries) = entry.additionalProperties["processedEntries"] {
        self.processedEntries = UInt64(processedEntries)
      } else {
        return nil
      }
    }
  }

  // TODO: Observable upload/download stats based on known log format?
  private struct Logger: Stderr {
    private let pipe: Pipe
    private let task: Task<Void, Swift.Error>

    init(
      onDownloadProgress: (@MainActor (DownloadProgress) -> Void)?,
      onUploadProgress: (@MainActor (UploadProgress) -> Void)?
    ) {
      let pipe = Pipe()

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601

      self.pipe = pipe
      self.task = Task {
        for try await line in pipe.fileHandleForReading.bytes.lines {
          let line = line.data(using: .utf8)!
          let entry = try decoder.decode(LogEntry.self, from: line)

          // Log the line
          switch entry.level {
          case "DEBUG":
            systemLogger.debug("\(entry.msg, privacy: .public)")
          case "INFO":
            systemLogger.info("\(entry.msg, privacy: .public)")
          case "WARN":
            systemLogger.warning("\(entry.msg, privacy: .public): \(entry.error ?? "", privacy: .public)")
          case "ERROR":
            systemLogger.error(
              "\(entry.msg, privacy: .public): \(entry.error ?? "", privacy: .public)")
          default:
            systemLogger.info("\(entry.msg, privacy: .public)")
          }

          // Try to interpret progress reporting
          switch entry.msg {
          case "Upload in progress":
            if let entry = UploadProgress(fromEntry: entry) {
              await onUploadProgress?(entry)
            }
          case "Download in progress":
            if let entry = DownloadProgress(fromEntry: entry) {
              await onDownloadProgress?(entry)
            }
          default:
            break
          }

        }
      }
    }

    var file: File {
      return .pipe(self.pipe)
    }

    func wait() async throws {
      let _ = try await self.task.value
    }
  }

  enum Error: Swift.Error {
    case unexpectedError
  }

  private static var url: URL {
    return Bundle.main.bundleURL
      .appendingPathComponent("Contents/MacOS/StewardTool")
  }

  private static func run(
    environment: [String: String], arguments: [String], stdin: StewardTool.Stdin?,
    stdout: StewardTool.Stdout?,
    stderr: StewardTool.Stderr?
  ) throws -> Task<Void, Swift.Error> {
    let process = Process()
    process.executableURL = self.url
    process.environment = environment
    process.arguments = arguments

    switch stdin?.file {
    case .fileHandle(let f):
      process.standardInput = f
    case .pipe(let p):
      process.standardInput = p
    case .none:
      break
    }

    switch stdout?.file {
    case .fileHandle(let f):
      process.standardOutput = f
    case .pipe(let p):
      process.standardOutput = p
    case .none:
      break
    }

    switch stderr?.file {
    case .fileHandle(let f):
      process.standardError = f
    case .pipe(let p):
      process.standardError = p
    case .none:
      break
    }

    try process.run()

    return Task {
      try await stdin?.wait()

      process.waitUntilExit()

      try await stdout?.wait()

      try await stderr?.wait()

      if process.terminationStatus != 0 {
        throw StewardTool.Error.unexpectedError
      }
    }
  }

  public static func index(roots: [URL], to outputPath: URL) throws -> Task<Void, Swift.Error> {
    return try self.run(
      environment: [:],
      arguments: ["--verbose", "index"] + roots.map({ x in x.path(percentEncoded: false) }),
      stdin: nil,
      stdout: try StewardTool.FileWriter(outputPath: outputPath),
      stderr: StewardTool.Logger(onDownloadProgress: nil, onUploadProgress: nil),
    )
  }

  // TODO: Return protocol for observable updates (which Logger implements)?
  public static func index(roots: [URL]) throws -> Task<[IndexEntry], Swift.Error> {
    let stdout = StewardTool.Decoder<IndexEntry>()
    let task = try self.run(
      environment: [:],
      arguments: ["--verbose", "index"] + roots.map({ x in x.path(percentEncoded: false) }),
      stdin: nil,
      stdout: stdout,
      stderr: StewardTool.Logger(onDownloadProgress: nil, onUploadProgress: nil),
    )

    return Task {
      let _ = try await task.value
      return try await stdout.values()
    }
  }

  public static func upload(
    root: URL, entries: [IndexEntry], force: Bool,
    _ onProgress: @MainActor @escaping (UploadProgress) -> Void
  ) throws -> Task<Void, Swift.Error> {
    guard let credentials = try GetCredentials() else {
      throw Error.unexpectedError
    }

    let logger = StewardTool.Logger(onDownloadProgress: nil, onUploadProgress: onProgress)

    return try self.run(
      environment: [
        "B2_REGION": credentials.region,
        "B2_KEY": credentials.key,
        "B2_SECRET": credentials.secret,
      ],
      arguments: [
        "--verbose", "upload", "--from", root.path(percentEncoded: false), "--to",
        credentials.bucket,
      ] + (force ? ["--force"] : []) + ["-"],
      stdin: StewardTool.Encoder(entries: entries),
      stdout: nil,
      stderr: logger,
    )
  }

  public static func diff(local: URL, remote: [IndexEntry])
    throws -> Task<[IndexEntry], Swift.Error>
  {
    let stdout = StewardTool.Decoder<IndexEntry>()
    let task = try self.run(
      environment: [:],
      arguments: [
        "--verbose", "diff", "--output", "remote-only", local.path(percentEncoded: false),
        "/dev/stdin",
      ],
      stdin: StewardTool.Encoder(entries: remote),
      stdout: stdout,
      stderr: StewardTool.Logger(onDownloadProgress: nil, onUploadProgress: nil),
    )

    return Task {
      let _ = try await task.value
      return try await stdout.values()
    }
  }

  public static func download(
    root: URL, entries: [IndexEntry], force: Bool,
    _ onProgress: @MainActor @escaping (DownloadProgress) -> Void
  ) throws -> (Task<Void, Swift.Error>) {
    guard let credentials = try GetCredentials() else {
      throw Error.unexpectedError
    }

    let logger = StewardTool.Logger(onDownloadProgress: onProgress, onUploadProgress: nil)

    return try self.run(
      environment: [
        "B2_REGION": credentials.region,
        "B2_KEY": credentials.key,
        "B2_SECRET": credentials.secret,
      ],
      arguments: [
        "--verbose", "download", "--from", credentials.bucket, "--to",
        root.path(percentEncoded: false),
      ] + (force ? ["--force"] : []) + ["-"],
      stdin: StewardTool.Encoder(entries: entries),
      stdout: nil,
      stderr: logger,
    )
  }
}

func readIndex(from url: URL) throws -> Task<[IndexEntry], Error> {
  let handle = try FileHandle(forReadingFrom: url)

  return Task {
    var entries = [IndexEntry]()

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    for try await line in handle.bytes.lines {
      let entry = try decoder.decode(IndexEntry.self, from: line.data(using: .utf8)!)
      entries.append(entry)
    }

    return entries
  }
}
