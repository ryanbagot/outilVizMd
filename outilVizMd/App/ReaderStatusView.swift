import SwiftUI

struct ReaderStatusView: View {
    let failure: ReaderFailure
    let stale: Bool
    @Bindable var model: ReadingCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(stale ? "Aperçu non à jour" : "Une action est nécessaire", systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text(failure.message).textSelection(.enabled)
            HStack {
                ForEach(failure.recoveries, id: \.self) { action in
                    switch action {
                    case .selectFile: Button("Choisir un fichier") { Task { await model.chooseFile() } }
                    case .selectFolder: ResourceAccessNoticeView(model: model)
                    case .retry: Button("Réessayer") { model.notice = nil; model.refreshActive() }
                    case .close: Button("Fermer") { model.notice = nil; if let id = model.activeDocumentID { model.close(id) } }
                    case .resetPreferences: Button("Réinitialiser les réglages") { model.resetPreferences(); model.notice = nil }
                    }
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(.yellow.opacity(0.12))
        .accessibilityElement(children: .contain)
    }
}
