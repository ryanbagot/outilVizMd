import SwiftUI

@main
@MainActor
struct OutilVizMdApp: App {
    @State private var model = ReadingCoordinator(preferencesStore: PreferencesStore(url: LocalFontCatalog.preferencesURL(), availableFonts: Set(LocalFontCatalog.identifiers)))
    var body: some Scene {
        Window("outilVizMd", id: "reader") {
            ReaderWindow(model: model)
                .task { await model.loadPreferences() }
                .preferredColorScheme(model.preferences.theme == .system ? nil : model.preferences.theme == .dark ? .dark : .light)
        }
        .commands { ReaderCommands(model: model) }
        Settings { PreferencesView(model: model) }
        Window("Aide outilVizMd", id: "help") { HelpView(resource: "Aide", fileExtension: "md") }
        Window("Licences des composants", id: "licenses") { HelpView(resource: "ThirdPartyNotices", fileExtension: "txt") }
    }
}
