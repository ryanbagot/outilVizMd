import AppKit
import SwiftUI

struct PreferencesView: View {
    @Bindable var model: ReadingCoordinator
    @Environment(\.colorScheme) private var systemScheme
    private let fonts = LocalFontCatalog.identifiers
    private var resolved: ResolvedTheme { ThemeResolver.resolve(model.preferences, systemDark: systemScheme == .dark) }

    private func binding<Value>(_ key: WritableKeyPath<RenderPreferences, Value>) -> Binding<Value> {
        Binding(get: { model.preferences[keyPath: key] }, set: { value in
            var prefs = model.preferences; prefs[keyPath: key] = value; model.updatePreferences(prefs)
        })
    }
    private func color(_ key: WritableKeyPath<ReadingPalette, SRGBColor>) -> Binding<Color> {
        Binding(get: {
            let c = resolved.palette[keyPath: key]
            return Color(.sRGB, red: c.red, green: c.green, blue: c.blue)
        }, set: { value in
            guard let converted = NSColor(value).usingColorSpace(.sRGB), let color = SRGBColor(red: converted.redComponent, green: converted.greenComponent, blue: converted.blueComponent) else { return }
            var prefs = model.preferences
            if resolved.dark { prefs.darkPalette[keyPath: key] = color } else { prefs.lightPalette[keyPath: key] = color }
            model.updatePreferences(prefs)
        })
    }

    var body: some View {
        Form {
            Picker("Apparence", selection: binding(\.theme)) {
                Text("Système").tag(RenderPreferences.Theme.system)
                Text("Claire").tag(RenderPreferences.Theme.light)
                Text("Sombre").tag(RenderPreferences.Theme.dark)
            }.accessibilityIdentifier("preference-theme")
            Picker("Police", selection: Binding(get: { model.preferences.fontIdentifier ?? "" }, set: { value in
                var prefs = model.preferences
                prefs.selectFont(value.isEmpty ? nil : value, availableIdentifiers: Set(fonts))
                model.updatePreferences(prefs)
            })) {
                Text("Police système").tag("")
                ForEach(fonts, id: \.self) { Text($0).tag($0) }
            }.accessibilityIdentifier("preference-font")
            Stepper("Taille : \(Int(model.preferences.fontSize)) pt", value: Binding(get: { model.preferences.fontSize }, set: { value in
                var prefs = model.preferences; if prefs.setFontSize(value) { model.updatePreferences(prefs) }
            }), in: 12...32, step: 1).accessibilityIdentifier("preference-size")
            Picker("Espacement", selection: binding(\.style)) {
                Text("Standard").tag(RenderPreferences.Style.standard)
                Text("Compact").tag(RenderPreferences.Style.compact)
                Text("Aéré").tag(RenderPreferences.Style.airy)
            }.accessibilityIdentifier("preference-style")
            Section(resolved.dark ? "Couleurs de l’apparence sombre" : "Couleurs de l’apparence claire") {
                ColorPicker("Texte", selection: color(\.text), supportsOpacity: false)
                ColorPicker("Fond", selection: color(\.background), supportsOpacity: false)
                ColorPicker("Liens", selection: color(\.link), supportsOpacity: false)
                if resolved.hasLowContrast {
                    Label("Le contraste du texte ou des liens est inférieur à 4,5:1. Votre choix reste appliqué.", systemImage: "eye.trianglebadge.exclamationmark").font(.callout)
                }
                Button("Rétablir ces couleurs") {
                    var prefs = model.preferences
                    if resolved.dark { prefs.darkPalette = .dark } else { prefs.lightPalette = .light }
                    model.updatePreferences(prefs)
                }
            }
            if let warning = model.preferencesWarning { Text(warning.message).foregroundStyle(.secondary).accessibilityIdentifier("preferences-warning") }
            Button("Réinitialiser tous les réglages") { model.resetPreferences() }.accessibilityIdentifier("preferences-reset")
            Text("Seuls les réglages de lecture sont conservés. Les documents et les autorisations ne sont pas restaurés au lancement.").font(.caption).foregroundStyle(.secondary)
        }.formStyle(.grouped).padding(12).frame(width: 520, height: 540)
            .preferredColorScheme(model.preferences.theme == .system ? nil : model.preferences.theme == .dark ? .dark : .light)
    }
}
