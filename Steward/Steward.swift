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

func index(roots: [URL], outputPath: URL) throws -> Task<Void, Error> {
    FileManager.default.createFile(atPath: outputPath.path, contents: nil)
    
    let fileHandle = try FileHandle(forWritingTo: outputPath)
        
    let toolURL = Bundle.main.bundleURL
      .appendingPathComponent("Contents/MacOS/StewardTool")

    let process = Process()
    process.executableURL = toolURL
    process.arguments = ["index"] + roots.map({ x in x.path(percentEncoded: false) })

    process.standardOutput = fileHandle
    
    try process.run()
    
    return Task {
        process.waitUntilExit()
        try? fileHandle.close()
        
        if process.terminationStatus != 0 {
            throw IndexError.unexpectedError
        }
    }
}

func index(roots: [URL]) throws -> Task<[IndexEntry], Error> {
    let toolURL = Bundle.main.bundleURL
      .appendingPathComponent("Contents/MacOS/StewardTool")

    let process = Process()
    process.executableURL = toolURL
    process.arguments = ["index"] + roots.map({ x in x.path(percentEncoded: false) })

    let stdout = Pipe()
    process.standardOutput = stdout
    
    
    try process.run()
    
    return Task {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        var entries = [IndexEntry]()
        
        for try await line in stdout.fileHandleForReading.bytes.lines {
            let entry = try decoder.decode(IndexEntry.self, from: line.data(using: String.Encoding.utf8)!)
            entries.append(entry)
        }
        
        // TODO: Output logs

        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw IndexError.unexpectedError
        }
        
        return entries
    }
}

enum UploadError : Error {
    case unexpectedError
}

func upload(root: URL, entries: [IndexEntry]) throws -> Task<Void, Error> {
    guard let credentials = try GetCredentials() else {
        throw UploadError.unexpectedError
    }
    
    let toolURL = Bundle.main.bundleURL
      .appendingPathComponent("Contents/MacOS/StewardTool")

    let process = Process()
    process.executableURL = toolURL
    process.arguments = ["upload", "--from", root.path(percentEncoded: false), "--to", credentials.bucket]
    process.environment = [
        "B2_REGION": credentials.region,
        "B2_KEY": credentials.key,
        "B2_SECRET": credentials.secret,
    ]
    
    let stdin = Pipe()
    process.standardInput = stdin

    let stdout = Pipe()
    process.standardOutput = stdout
    
    try process.run()
    
    return Task {
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


func diff(local: URL, remote: [IndexEntry]) throws -> Task<[IndexEntry], Error> {
    let toolURL = Bundle.main.bundleURL
      .appendingPathComponent("Contents/MacOS/StewardTool")

    let process = Process()
    process.executableURL = toolURL
    process.arguments = ["diff", "--output", "remote-only", local.path(percentEncoded: false), "/dev/stdin"]
    
    let stdin = Pipe()
    process.standardInput = stdin

    let stdout = Pipe()
    process.standardOutput = stdout
    
    try process.run()
    
    return Task {
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
        
        // TODO: Output logs

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

func download(root: URL, entries: [IndexEntry]) throws -> Task<Void, Error> {
    guard let credentials = try GetCredentials() else {
        throw DownloadError.unexpectedError
    }
    
    let toolURL = Bundle.main.bundleURL
      .appendingPathComponent("Contents/MacOS/StewardTool")

    let process = Process()
    process.executableURL = toolURL
    process.arguments = ["download", "--from", credentials.bucket, "--to", root.path(percentEncoded: false)]
    process.environment = [
        "B2_REGION": credentials.region,
        "B2_KEY": credentials.key,
        "B2_SECRET": credentials.secret,
    ]
    
    let stdin = Pipe()
    process.standardInput = stdin

    let stdout = Pipe()
    process.standardOutput = stdout
    
    try process.run()
    
    return Task {
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
