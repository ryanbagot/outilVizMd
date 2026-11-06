import SwiftUI

struct ResourceAccessNoticeView: View {
    @Bindable var model: ReadingCoordinator
    var body: some View {
        Button("Autoriser un dossier") { Task { await model.chooseFolder() } }
            .help("Choisissez explicitement le dossier contenant le document et ses images locales. Les images distantes restent indisponibles.")
            .accessibilityLabel("Autoriser explicitement un dossier pour les ressources locales")
    }
}
