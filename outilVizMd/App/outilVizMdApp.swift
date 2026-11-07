import SwiftUI

@main
@MainActor
struct OutilVizMdApp: App {
    @NSApplicationDelegateAdaptor(ReaderAppDelegate.self) private var appDelegate
    @State private var model = ReadingCoordinator(preferencesStore: PreferencesStore(url: LocalFontCatalog.preferencesURL(), availableFonts: Set(LocalFontCatalog.identifiers)))
    var body: some Scene {
        Window("outilVizMd", id: "reader") {
            ReaderWindow(model: model)
                .background(ReaderWindowRegistration(delegate: appDelegate).frame(width: 0, height: 0).allowsHitTesting(false))
                .task { await model.loadPreferences() }
                .preferredColorScheme(model.preferences.theme == .system ? nil : model.preferences.theme == .dark ? .dark : .light)
        }
        .commands { ReaderCommands(model: model) }
        Settings { PreferencesView(model: model) }
        Window("Aide outilVizMd", id: "help") { HelpView(resource: "Aide", fileExtension: "md") }
        Window("Licences des composants", id: "licenses") { HelpView(resource: "ThirdPartyNotices", fileExtension: "txt") }
    }
}

// La visibilité de l’aide ou des réglages ne dit pas si le lecteur est présenté.
@MainActor
final class ReaderAppDelegate: NSObject, NSApplicationDelegate {
    weak var readerWindow: NSWindow?
    var openReader: (() -> Void)?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if readerWindow?.isVisible != true { openReader?() }
        DispatchQueue.main.async { [weak self] in
            // Un panneau de sélection déjà ouvert reste prioritaire au lecteur.
            if let panel = sender.windows.first(where: { $0 is NSOpenPanel && $0.isVisible }) {
                panel.makeKeyAndOrderFront(nil)
                return
            }
            self?.readerWindow?.deminiaturize(nil)
            self?.readerWindow?.makeKeyAndOrderFront(nil)
            sender.activate(ignoringOtherApps: true)
        }
        return false
    }
}

private struct ReaderWindowRegistration: NSViewRepresentable {
    let delegate: ReaderAppDelegate
    @Environment(\.openWindow) private var openWindow

    func makeNSView(context: Context) -> WindowProbe { WindowProbe() }
    func updateNSView(_ view: WindowProbe, context: Context) {
        delegate.openReader = { openWindow(id: "reader") }
        view.register = { [weak delegate] window in delegate?.readerWindow = window }
        if let window = view.window { delegate.readerWindow = window }
    }

    final class WindowProbe: NSView {
        var register: ((NSWindow) -> Void)?
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { register?(window) }
        }
    }
}
