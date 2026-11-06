import SwiftUI

struct ReaderWindow: View {
    @Bindable var model: ReadingCoordinator
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model)
        } detail: {
            VStack(spacing: 0) {
                if model.isSearchPresented {
                    SearchBar(model: model) {
                        model.closeSearch()
                        if let id = model.activeDocumentID, let controller = model.controller(for: id) { controller.webView.window?.makeFirstResponder(controller.webView) }
                    }
                }
                if let warning = model.preferencesWarning { ReaderStatusView(failure: warning, stale: false, model: model) }
                if let notice = model.notice {
                    ReaderStatusView(failure: notice, stale: false, model: model)
                }
                if let id = model.activeDocumentID, let state = model.documents[id] {
                    if state.status == .loading {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Chargement du document…")
                            Spacer()
                            Button("Annuler") { model.close(id) }
                        }.padding(12)
                    }
                    if let failure = state.failure {
                        ReaderStatusView(failure: failure, stale: state.preview != nil, model: model)
                    }
                    if state.snapshot?.text.isEmpty == true {
                        ContentUnavailableView("Document vide", systemImage: "doc", description: Text("Ce document ne contient pas encore de texte."))
                    } else if let controller = model.controller(for: id) {
                        PreviewWebView(controller: controller).id(id)
                    } else if state.status != .loading {
                        ContentUnavailableView("Aucun aperçu disponible", systemImage: "doc.badge.ellipsis", description: Text("Réessayez ou choisissez un autre fichier."))
                    } else { Spacer() }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.richtext").font(.system(size: 54)).foregroundStyle(.tint)
                        Text("Vos documents, simplement.").font(.largeTitle.bold()).accessibilityIdentifier("welcome-title")
                        Text("Ouvrez un fichier Markdown pour le lire.\nChoisissez son dossier pour autoriser aussi ses images locales.")
                            .foregroundStyle(.secondary).multilineTextAlignment(.center)
                        HStack(spacing: 12) {
                            Button("Ouvrir un fichier") { Task { await model.chooseFile() } }.buttonStyle(.borderedProminent).accessibilityIdentifier("welcome-open-file")
                            Button("Ouvrir un dossier") { Task { await model.chooseFolder() } }.buttonStyle(.bordered).accessibilityIdentifier("welcome-open-folder")
                        }
                        Text("Lecture seule · Aucun document modifié").font(.caption).foregroundStyle(.secondary)
                    }.padding(40).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(model.activeDocumentID.flatMap { model.documents[$0]?.handle.displayName } ?? "outilVizMd")
            .toolbar {
                ToolbarItemGroup {
                    Button { Task { await model.chooseFile() } } label: { Label("Ouvrir un fichier", systemImage: "doc.badge.plus") }
                    Button { Task { await model.chooseFolder() } } label: { Label("Ouvrir un dossier", systemImage: "folder") }
                    Button { model.refreshActive() } label: { Label("Actualiser le document", systemImage: "arrow.clockwise") }.disabled(model.activeDocumentID == nil)
                    Button { if let id = model.activeDocumentID { model.close(id) } } label: { Label("Fermer le document", systemImage: "xmark") }.disabled(model.activeDocumentID == nil)
                }
            }
        }
        .frame(minWidth: 840, minHeight: 560)
        .focusedSceneValue(\.readingCoordinator, model)
        .onChange(of: scenePhase) { _, phase in if phase == .active { model.reactivate() } }
    }
}
