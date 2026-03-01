import SwiftData
import SwiftUI

@main
struct StewardApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }

    Settings {
      SettingsView()
    }
  }
}
