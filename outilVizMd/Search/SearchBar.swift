import SwiftUI

struct SearchBar: View {
    @Bindable var model: ReadingCoordinator
    @FocusState private var focused: Bool
    let onClose: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").accessibilityHidden(true)
            TextField("Rechercher dans ce document", text: Binding(get: { model.searchQuery }, set: { model.updateSearch($0) }))
                .textFieldStyle(.roundedBorder).focused($focused).accessibilityIdentifier("search-query")
                .onSubmit { model.moveSearch(1) }
            Text(model.searchState?.counter ?? (model.searchQuery.isEmpty ? "" : "Recherche…"))
                .font(.callout).monospacedDigit().accessibilityIdentifier("search-counter")
            Button { model.moveSearch(-1) } label: { Image(systemName: "chevron.up") }
                .accessibilityLabel("Résultat précédent").disabled(model.searchState?.total ?? 0 == 0)
            Button { model.moveSearch(1) } label: { Image(systemName: "chevron.down") }
                .accessibilityLabel("Résultat suivant").disabled(model.searchState?.total ?? 0 == 0)
            Button("Terminer") { onClose() }.accessibilityIdentifier("search-close")
        }.padding(10)
            .onAppear { focused = true }
            .onExitCommand { onClose() }
    }
}
