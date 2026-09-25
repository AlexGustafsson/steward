import SwiftUI

struct IndexEntryInspector: View {
  var entry: IndexEntry
  public var sarifRules: [String: SarifRule]?

  @ContentBuilder
  var sarifSection: some View {
    let rules: [String: SarifRule] = sarifRules ?? [:]
    let results: [SarifResult] = entry.sarif ?? []

    Section("Linting") {
      ForEach(results.indices, id: \.self) { index in
        let result: SarifResult = results[index]
        let rule: SarifRule? = rules[result.ruleId]

        let name = rule?.name ?? ""
        let text = rule?.shortDescription.text ?? ""

        let level = rule?.defaultConfiguration?.level
        let systemImage =
          level == .error
          ? "x.circle.fill"
          : level == .warning
            ? "exclamationmark.circle.fill"
            : "info.circle.fill"

        let style =
          level == .error
          ? Color.red
          : level == .warning
            ? Color.orange
            : Color.blue

        Section {
          Text(text)
        } header: {
          Label(name, systemImage: systemImage)
            .foregroundStyle(style)
        }
      }
    }
  }

  var body: some View {
    Section("Overview") {
      HStack {
        Text("Album artist")
        Spacer()
        if let v = entry.albumArtist {
          Text(v)
        } else {
          Text("N/A").foregroundStyle(.secondary)
        }
      }
      HStack {
        Text("Artist")
        Spacer()
        if let v = entry.artist {
          Text(v)
        } else {
          Text("N/A").foregroundStyle(.secondary)
        }
      }
      HStack {
        Text("Album")
        Spacer()
        if let v = entry.album {
          Text(v)
        } else {
          Text("N/A").foregroundStyle(.secondary)
        }
      }
      HStack {
        Text("Size")
        Spacer()
        Text(
          ByteCountFormatter.string(
            from: .init(value: Double(entry.size), unit: .bytes), countStyle: .memory))
      }
    }
    Section("Identity") {
      HStack {
        Text("Name")
        Spacer()
        Text(entry.name)
      }
      HStack {
        Text("Audio digest")
        Spacer()
        Text(entry.audioDigest)
      }
      HStack {
        Text("Picture digest")
        Spacer()
        Text(entry.pictureDigest)
      }
    }
    Section("Raw tags") {
      ForEach(entry.metadataKeyValue, id: \.id) { entry in
        HStack {
          Text(entry.key)
          Spacer()
          Text(entry.value)
        }
      }
    }
    sarifSection
  }
}

struct IndexEntryInspectorForm: View {
  var entries: [IndexEntry]
  var selection: Set<IndexEntry.ID>
  public var sarifRules: [String: SarifRule]?

  @State var entry: IndexEntry? = nil

  var body: some View {
    Form {
      if let entry = entry {
        IndexEntryInspector(
          entry: entry, sarifRules: sarifRules)
      } else if selection.count > 1 {
        ContentUnavailableView {
          Image(systemName: "magnifyingglass.circle")
        } description: {
          Text("Select a single track to inspect")
        }
      } else if selection.count == 0 {
        ContentUnavailableView {
          Image(systemName: "magnifyingglass.circle")
        } description: {
          Text("Select a track to inspect")
        }
      }
    }.onChange(of: selection) {
      if selection.count == 1 {
        entry = entries.first(where: { $0.id == selection.first })
      } else {
        entry = nil
      }
    }
  }
}

#Preview {
  let entries: [IndexEntry] = [
    IndexEntry(
      name: "/user/alex/1", modTime: .now, size: 30_000_000, metadata: ["ALBUM=Wet wet wet"],
      audioDigest: "md5:b1946ac92492d2347c6235b4d2611184",
      pictureDigest: "md5:d41d8cd98f00b204e9800998ecf8427e"),
    IndexEntry(
      name: "/user/alex/2", modTime: .now, size: 30_000_000, metadata: ["ALBUM=We can't dance"],
      audioDigest: "md5:a10edbbb8f28f8e98ee6b649ea2556f4",
      pictureDigest: "md5:d41d8cd98f00b204e9800998ecf8427e"),
  ]

  let selection: Set<IndexEntry.ID> = ["/user/alex/1"]

  IndexEntryInspectorForm(entries: entries, selection: selection)
}
