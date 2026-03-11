import Foundation

struct IndexEntry: Identifiable, Codable {
  public var name: String
  public var modTime: Date
  public var size: Int64
  public var metadata: [String]
  public var audioDigest: String
  public var pictureDigest: String

  var id: String {
    return self.name
  }

  var disc: String? {
    return self.getMetadata("DISCNUMBER")?.first
  }

  var track: String? {
    return self.getMetadata("TRACKNUMBER")?.first
  }

  var album: String? {
    return self.getMetadata("ALBUM")?.first
  }

  var artist: String? {
    return self.getMetadata("ARTIST")?.first ?? self.getMetadata("ARTISTS")?.joined(separator: ", ")
  }

  var composer: String? {
    return self.getMetadata("COMPOSER")?.joined(separator: ", ")
  }

  var title: String? {
    return self.getMetadata("TITLE")?.first
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

enum JSONValue: Codable, Equatable {
  case string(String)
  case number(Double)
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
    switch self {
    case .string(let v):
      return v
    case .number(let v):
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

struct LogEntry: Codable {
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

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
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
