import SwiftUI

struct OpenDocumentsList: View {
    @Bindable var model: ReadingCoordinator

    var body: some View {
        ForEach(model.documentOrder, id: \.self) { id in
            if let state = model.documents[id] {
                VStack(alignment: .leading, spacing: 3) {
                    Label(state.handle.displayName, systemImage: "doc.text")
                    Text(state.handle.displayPath).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
                .padding(.vertical, 4).tag(id)
                .contextMenu { Button("Fermer") { model.close(id) } }
                .accessibilityLabel(state.handle.displayName + ", " + state.handle.displayPath)
                .accessibilityIdentifier("open-document-" + state.handle.displayPath)
            }
        }
    }
}
