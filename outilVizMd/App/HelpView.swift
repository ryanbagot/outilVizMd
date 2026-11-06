import SwiftUI

struct HelpView: View {
    let resource: String
    let fileExtension: String
    private var text: String {
        guard let url = Bundle.main.url(forResource: resource, withExtension: fileExtension), let text = try? String(contentsOf: url, encoding: .utf8) else { return "Cette aide locale n’est pas disponible dans le bundle." }
        return text
    }
    var body: some View {
        ScrollView { Text(text).textSelection(.enabled).accessibilityIdentifier("local-document-text").frame(maxWidth: .infinity, alignment: .leading).padding(28) }
            .frame(minWidth: 560, idealWidth: 720, minHeight: 420, idealHeight: 650)
    }
}
