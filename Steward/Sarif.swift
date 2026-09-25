import SwiftUI

struct Sarif: Codable {
  public var runs: [SarifRun]

  public func populate(entries: inout [IndexEntry], level: inout SarifLevel) -> [String: SarifRule]
  {
    let rules = Dictionary(
      uniqueKeysWithValues: self.runs.flatMap { run in
        return run.tool.driver.rules
      }.map { rule in
        return (rule.id, rule)
      })

    var results = [String: [SarifResult]]()

    for run in self.runs {
      for result in run.results {
        if result.level.sortOrder < level.sortOrder {
          level = result.level
        }

        for location in result.locations {
          var partial = results[location.fullyQualifiedName] ?? [SarifResult]()
          partial.append(result)
          results[location.fullyQualifiedName] = partial
        }
      }
    }

    for i in entries.indices {
      entries[i].sarif = results[entries[i].name]?.sorted {
        $0.level.sortOrder < $1.level.sortOrder
      }
    }

    return rules
  }
}

struct SarifRun: Codable {
  public var tool: SarifTool
  public var results: [SarifResult]
}

struct SarifTool: Codable {
  public var driver: SarifDriver
}

struct SarifDriver: Codable {
  public var name: String
  public var version: String
  public var rules: [SarifRule]
}

struct SarifRule: Codable {
  public var id: String
  public var name: String
  public var shortDescription: SarifMessage
  public var fullDescription: SarifMessage?
  public var defaultConfiguration: SarifRuleConfiguration?
}

struct SarifMessage: Codable {
  public var text: String
}

struct SarifRuleConfiguration: Codable {
  public var level: SarifLevel
}

struct SarifResult: Codable {
  public var ruleId: String
  public var level: SarifLevel
  public var locations: [SarifLogicalLocation]
}

enum SarifLevel: String, Codable {
  case none = "none"
  case note = "note"
  case warning = "warning"
  case error = "error"

  var sortOrder: Int {
    switch self {
    case .error: return 0
    case .warning: return 1
    case .note: return 2
    case .none: return 3
    }
  }
}

struct SarifLogicalLocation: Codable {
  public var kind: String
  public var fullyQualifiedName: String
}

extension SarifLevel {
  var color: Color {
    switch self {
    case .error: return .red
    case .warning: return .orange
    case .note: return .blue
    case .none: return .blue
    }
  }
}

extension SarifLevel {
  var systemName: String {
    switch self {
    case .error: return "x.circle.fill"
    case .warning: return "exclamationmark.circle.fill"
    case .note: return "info.circle.fill"
    case .none: return "info.circle.fill"
    }
  }
}
