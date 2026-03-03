import Foundation

struct IndexEntry: Identifiable, Codable {
    public var name:          String
    public var modTime:       Date
    public var size: Int64
    public var metadata:     [String]
    public var audioDigest : String
    public var pictureDigest: String
    
    var id: String {
        get {
            return self.name
        }
    }
    
    var disc: String? {
        get {
            return self.getMetadata("DISCNUMBER")?.first
        }
    }
    
    var track: String? {
        get {
            return self.getMetadata("TRACKNUMBER")?.joined(separator: ", ")
        }
    }
    
    var album: String? {
        get {
            return self.getMetadata("ALBUM")?.first
        }
    }
    
    var artist: String? {
        get {
            return self.getMetadata("ARTIST")?.first ?? self.getMetadata("ARTISTS")?.joined(separator: ", ")
        }
    }
    
    var composer: String? {
        get {
            return self.getMetadata("COMPOSER")?.joined(separator: ", ")
        }
    }
    
    var title: String? {
        get {
            return self.getMetadata("TITLE")?.first
        }
    }
    
    func getMetadata(_ key: String) -> [String]? {
        let values = self.metadata
            .enumerated()
            .filter({ $0.element.hasPrefix(key + "=") })
            .map({
                let index = $0.element.index(after: ($0.element.firstIndex(of: "=")!))
                return String($0.element[index...])
            })
        if values.count > 0 {
            return values
        }
        
        return nil
    }
    
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case modTime = "ModTime"
        case size = "Size"
        case metadata = "Metadata"
        case audioDigest = "AudioDigest"
        case pictureDigest = "PictureDigest"
    }
}

enum IndexError: Error {
    case unexpectedError
}

func index(roots: [URL], outputPath: URL, _ logCallback: @escaping @MainActor (LogEntry) -> ()) throws -> Task<Void, Error> {
    FileManager.default.createFile(atPath: outputPath.path, contents: nil)
    
    let fileHandle = try FileHandle(forWritingTo: outputPath)
        
    let toolURL = Bundle.main.bundleURL
      .appendingPathComponent("Contents/MacOS/StewardTool")

    let process = Process()
    process.executableURL = toolURL
    process.arguments = ["--verbose", "index"] + roots.map({ x in x.path(percentEncoded: false) })

    process.standardOutput = fileHandle
    
    let stderr = Pipe()
    process.standardError = stderr
    
    try process.run()
    
    return Task {
        let logsTask = readLogs(fileHandle: stderr.fileHandleForReading, logCallback)
        
        process.waitUntilExit()
        try? fileHandle.close()
        
        let _ = try? await logsTask.value
        
        if process.terminationStatus != 0 {
            throw IndexError.unexpectedError
        }
    }
}

func index(roots: [URL], _ logCallback: @escaping @MainActor (LogEntry) -> ()) throws -> Task<[IndexEntry], Error> {
    let toolURL = Bundle.main.bundleURL
      .appendingPathComponent("Contents/MacOS/StewardTool")

    let process = Process()
    process.executableURL = toolURL
    process.arguments = ["--verbose", "index"] + roots.map({ x in x.path(percentEncoded: false) })

    let stdout = Pipe()
    process.standardOutput = stdout
    
    let stderr = Pipe()
    process.standardError = stderr
    
    try process.run()
    
    return Task {
        let logsTask = readLogs(fileHandle: stderr.fileHandleForReading, logCallback)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        var entries = [IndexEntry]()
        
        for try await line in stdout.fileHandleForReading.bytes.lines {
            let entry = try decoder.decode(IndexEntry.self, from: line.data(using: String.Encoding.utf8)!)
            entries.append(entry)
        }
        
        // TODO: Output logs

        process.waitUntilExit()
        
        let _ = try? await logsTask.value
        
        if process.terminationStatus != 0 {
            throw IndexError.unexpectedError
        }
        
        return entries
    }
}

enum UploadError : Error {
    case unexpectedError
}

func upload(root: URL, entries: [IndexEntry], _ logCallback: @escaping @MainActor (LogEntry) -> ()) throws -> Task<Void, Error> {
    guard let credentials = try GetCredentials() else {
        throw UploadError.unexpectedError
    }
    
    let toolURL = Bundle.main.bundleURL
      .appendingPathComponent("Contents/MacOS/StewardTool")

    let process = Process()
    process.executableURL = toolURL
    process.arguments = ["--verbose", "upload", "--from", root.path(percentEncoded: false), "--to", credentials.bucket]
    process.environment = [
        "B2_REGION": credentials.region,
        "B2_KEY": credentials.key,
        "B2_SECRET": credentials.secret,
    ]
    
    let stdin = Pipe()
    process.standardInput = stdin

    let stderr = Pipe()
    process.standardError = stderr
    
    try process.run()
    
    return Task {
        let logsTask = readLogs(fileHandle: stderr.fileHandleForReading, logCallback)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        for entry in entries {
            let line = try encoder.encode(entry)
            try stdin.fileHandleForWriting.write(contentsOf: line)
            try stdin.fileHandleForWriting.write(contentsOf: "\n".data(using: .utf8)!)
        }
        try? stdin.fileHandleForWriting.close()

        process.waitUntilExit()
        
        let _ = try? await logsTask.value
        
        if process.terminationStatus != 0 {
            throw UploadError.unexpectedError
        }
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

enum DiffError: Error {
    case unexpectedError
}


func diff(local: URL, remote: [IndexEntry], _ logCallback: @escaping @MainActor (LogEntry) -> ()) throws -> Task<[IndexEntry], Error> {
    let toolURL = Bundle.main.bundleURL
      .appendingPathComponent("Contents/MacOS/StewardTool")

    let process = Process()
    process.executableURL = toolURL
    process.arguments = ["--verbose", "diff", "--output", "remote-only", local.path(percentEncoded: false), "/dev/stdin"]
    
    let stdin = Pipe()
    process.standardInput = stdin

    let stdout = Pipe()
    process.standardOutput = stdout
    
    let stderr = Pipe()
    process.standardError = stderr
    
    try process.run()
    
    return Task {
        let _ = readLogs(fileHandle: stderr.fileHandleForReading, logCallback)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        for entry in remote {
            let line = try encoder.encode(entry)
            try stdin.fileHandleForWriting.write(contentsOf: line)
            try stdin.fileHandleForWriting.write(contentsOf: "\n".data(using: .utf8)!)
        }
        try? stdin.fileHandleForWriting.close()
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        var entries = [IndexEntry]()
        
        for try await line in stdout.fileHandleForReading.bytes.lines {
            let entry = try decoder.decode(IndexEntry.self, from: line.data(using: .utf8)!)
            entries.append(entry)
        }

        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw DiffError.unexpectedError
        }
        
        return entries
    }
}


enum DownloadError : Error {
    case unexpectedError
}

func download(root: URL, entries: [IndexEntry], _ logCallback: @escaping @MainActor (LogEntry) -> ()) throws -> Task<Void, Error> {
    guard let credentials = try GetCredentials() else {
        throw DownloadError.unexpectedError
    }
    
    let toolURL = Bundle.main.bundleURL
      .appendingPathComponent("Contents/MacOS/StewardTool")

    let process = Process()
    process.executableURL = toolURL
    process.arguments = ["--verbose", "download", "--from", credentials.bucket, "--to", root.path(percentEncoded: false)]
    process.environment = [
        "B2_REGION": credentials.region,
        "B2_KEY": credentials.key,
        "B2_SECRET": credentials.secret,
    ]
    
    let stdin = Pipe()
    process.standardInput = stdin

    let stdout = Pipe()
    process.standardOutput = stdout
    
    let stderr = Pipe()
    process.standardError = stderr
    
    try process.run()
    
    return Task {
        let _ = readLogs(fileHandle: stderr.fileHandleForReading, logCallback)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        for entry in entries {
            let line = try encoder.encode(entry)
            try stdin.fileHandleForWriting.write(contentsOf: line)
            try stdin.fileHandleForWriting.write(contentsOf: "\n".data(using: .utf8)!)
        }
        try? stdin.fileHandleForWriting.close()
        
        // TODO: Output logs

        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw UploadError.unexpectedError
        }
    }
}

enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case int(Int)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .number(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid JSON value"
            )
        }
    }
    
    var string: String {
        get {
            switch self {
            case .string(let v):
                return v
            case .number(let v):
                return v.formatted()
            case .int(let v):
                return v.formatted()
            case .bool(let v):
                return v ? "true" : "false"
            case .object:
                return "[Object]"
            case .array:
                return "[Array]"
            case .null:
                return "null"
            }
        }
    }
}

struct LogEntry: Codable, Identifiable {
    var id: Int
    var time: Date
    var level: String
    var msg: String
    var error: String?
    var additionalProperties: [String: JSONValue] = [:]
    
    enum CodningKeys: String, CodingKey {
        case time
        case level
        case msg
        case error
    }
    
    struct DynamicCodingKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }
    
    init(id: Int, time: Date, level: String, msg: String) {
        self.id = id
        self.time = time
        self.level = level
        self.msg = msg
    }
    
    init(id: Int, time: Date, level: String, msg: String, error: String) {
        self.id = id
        self.time = time
        self.level = level
        self.msg = msg
        self.error = error
    }
    
    init(id: Int, time: Date, level: String, msg: String, error: String, additionalProperties: [String: JSONValue]) {
        self.id = id
        self.time = time
        self.level = level
        self.msg = msg
        self.error = error
        self.additionalProperties = additionalProperties
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = 0
        self.time = try container.decode(Date.self, forKey: .time)
        self.level = try container.decode(String.self, forKey: .level)
        self.msg = try container.decode(String.self, forKey: .msg)
        self.error = try container.decodeIfPresent(String.self, forKey: .error)

        let dynamic = try decoder.container(keyedBy: DynamicCodingKey.self)
        for key in dynamic.allKeys {
            if CodingKeys(stringValue: key.stringValue) == nil {
                additionalProperties[key.stringValue] =
                    try dynamic.decode(JSONValue.self, forKey: key)
            }
        }
    }
}

func readLogs(fileHandle: FileHandle, _ callback: @escaping @MainActor (LogEntry) -> ()) -> Task<Void, Error> {
   return Task {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
       var lineIndex = 0
        for try await line in fileHandle.bytes.lines {
            do {
                var entry = try decoder.decode(LogEntry.self, from: line.data(using: .utf8)!)
                entry.id = lineIndex
                await callback(entry)
            } catch {
                print(error)
                return
            }
            lineIndex += 1
        }
    }
}
