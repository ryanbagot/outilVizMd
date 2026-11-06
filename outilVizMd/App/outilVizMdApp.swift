import SwiftUI

@main
struct OutilVizMdApp: App {
    var body: some Scene {
        Window("outilVizMd", id: "reader") {
            ContentUnavailableView {
                Label("outilVizMd", systemImage: "doc.richtext")
            } description: {
                Text("Le lecteur de documents Markdown est en cours de construction.")
            }
            .frame(minWidth: 760, minHeight: 520)
        }
    }
}
