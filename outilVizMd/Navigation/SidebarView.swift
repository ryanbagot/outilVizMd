import SwiftUI

struct SidebarView: View {
    @Bindable var model: ReadingCoordinator

    private struct Row: Identifiable {
        let entry: NavigationEntry
        let depth: Int
        var id: String { entry.id }
    }

    private var rows: [Row] {
        var result: [Row] = []
        func append(_ entries: [NavigationEntry], depth: Int) {
            for entry in entries {
                result.append(Row(entry: entry, depth: depth))
                if model.expandedDirectories.contains(entry.id), let children = entry.children { append(children, depth: depth + 1) }
            }
        }
        append(model.navigationRoots, depth: 0)
        return result
    }

    var body: some View {
        List(selection: Binding(get: { model.activeDocumentID }, set: { if let id = $0 { model.select(id) } })) {
            Section("Documents ouverts") { OpenDocumentsList(model: model) }
            if let folder = model.folderGrant {
                Section {
                    if model.navigationRoots.isEmpty {
                        Text("Aucun document dans ce dossier").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(rows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Button {
                                if row.entry.kind == .directory { model.toggleDirectory(row.entry.id) }
                                else { Task { await model.openDirectoryDocument(row.entry) } }
                            } label: {
                                HStack(spacing: 6) {
                                    if row.entry.kind == .directory {
                                        Image(systemName: model.expandedDirectories.contains(row.entry.id) ? "chevron.down" : "chevron.right").font(.caption2).frame(width: 10)
                                    } else { Color.clear.frame(width: 10, height: 1) }
                                    Label(row.entry.name, systemImage: row.entry.kind == .directory ? "folder" : "doc.text")
                                        .lineLimit(1).truncationMode(.middle)
                                    Spacer(minLength: 0)
                                }.contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(row.entry.kind == .directory ? "Dossier " + row.entry.name : row.entry.name)
                            .accessibilityIdentifier((row.entry.kind == .directory ? "directory-folder-" : "directory-document-") + row.entry.url.path)
                            if let failure = row.entry.failure { Text(failure.message).font(.caption).foregroundStyle(.secondary) }
                            else if row.entry.kind == .directory, model.expandedDirectories.contains(row.entry.id), row.entry.children?.isEmpty == true {
                                Text("Dossier vide").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.leading, CGFloat(row.depth) * 14)
                        .help(row.entry.url.path)
                    }
                } header: {
                    HStack {
                        Text(folder.resolvedRoot.lastPathComponent).lineLimit(1).help(folder.resolvedRoot.path)
                        Spacer()
                        Button { Task { await model.refreshDirectory() } } label: { Image(systemName: "arrow.clockwise") }
                            .buttonStyle(.plain).accessibilityLabel("Actualiser le dossier")
                    }
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 210, ideal: 280, max: 420)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button { Task { await model.chooseFile() } } label: { Label("Ouvrir un fichier", systemImage: "doc.badge.plus") }
                Button { Task { await model.chooseFolder() } } label: { Label("Ouvrir un dossier", systemImage: "folder.badge.plus") }
            }.labelStyle(.iconOnly).padding(12)
        }
    }
}
