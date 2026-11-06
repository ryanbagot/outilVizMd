import SwiftUI

struct ReaderCommands: Commands {
    let model: ReadingCoordinator
    @FocusedValue(\.readingCoordinator) private var focusedReader
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Ouvrir un fichier…") { Task { await model.chooseFile() } }.keyboardShortcut("o")
            Button("Ouvrir un dossier…") { Task { await model.chooseFolder() } }.keyboardShortcut("o", modifiers: [.command, .shift])
            Divider()
            Button("Fermer") {
                if focusedReader != nil, let id = model.activeDocumentID { model.close(id) }
                else { NSApp.keyWindow?.performClose(nil) }
            }.keyboardShortcut("w").disabled(focusedReader != nil && model.activeDocumentID == nil)
        }
        CommandGroup(replacing: .help) {
            Button("Aide outilVizMd") { openWindow(id: "help") }
            Button("Licences des composants") { openWindow(id: "licenses") }
        }
        CommandGroup(replacing: .saveItem) { }
        CommandGroup(after: .pasteboard) {
            Button("Rechercher…") { model.presentSearch() }.keyboardShortcut("f").disabled(model.activeDocumentID == nil)
            Button("Résultat suivant") { model.moveSearch(1) }.keyboardShortcut("g").disabled(model.searchState?.total ?? 0 == 0)
            Button("Résultat précédent") { model.moveSearch(-1) }.keyboardShortcut("g", modifiers: [.command, .shift]).disabled(model.searchState?.total ?? 0 == 0)
            Button("Actualiser le document") { model.refreshActive() }.keyboardShortcut("r").disabled(model.activeDocumentID == nil)
            Button("Actualiser le dossier") { Task { await model.refreshDirectory() } }.keyboardShortcut("r", modifiers: [.command, .shift]).disabled(model.folderGrant == nil)
        }
    }
}

private struct ReadingCoordinatorFocusKey: FocusedValueKey { typealias Value = ReadingCoordinator }
extension FocusedValues {
    var readingCoordinator: ReadingCoordinator? {
        get { self[ReadingCoordinatorFocusKey.self] }
        set { self[ReadingCoordinatorFocusKey.self] = newValue }
    }
}
