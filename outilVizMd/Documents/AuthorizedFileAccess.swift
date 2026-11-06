import Darwin
import Foundation

struct AuthorizedRead: Sendable {
    let bytes: Data
    let before: FileMetadata
    let after: FileMetadata
}

struct AuthorizedDirectoryItem: Sendable {
    let url: URL
    let identity: FileIdentity
    let isDirectory: Bool
}

/// Toute lecture passe par des descripteurs ancrés au choix explicite. Les descripteurs
/// de dossier ne sont jamais exposés aux consommateurs et n’élargissent pas le grant logique.
actor AuthorizedFileAccess {
    private struct Entry: Sendable {
        var grant: AccessGrant
        let descriptor: Int32
        let parentDescriptor: Int32?
    }
    private var entries: [UUID: Entry] = [:]

    deinit {
        for entry in entries.values {
            Darwin.close(entry.descriptor)
            if let parent = entry.parentDescriptor { Darwin.close(parent) }
        }
    }

    func matchingGrant(for url: URL) -> AccessGrant? {
        for entry in entries.values.sorted(by: { $0.grant.kind == .directory && $1.grant.kind == .file }) {
            if let fd = try? openAuthorized(url, grantID: entry.grant.id) {
                Darwin.close(fd)
                return entry.grant
            }
        }
        return nil
    }

    func authorizeSelectedURL(_ selected: URL, kind: AccessGrant.Kind) throws -> AccessGrant {
        let root = selected.resolvingSymlinksInPath().standardizedFileURL
        let descriptor = Darwin.open(root.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK | (kind == .directory ? O_DIRECTORY : 0))
        guard descriptor >= 0 else { throw Self.failure(errno) }
        var parent: Int32?
        do {
            let stat = try Self.stat(descriptor)
            guard kind == .directory ? Self.isDirectory(stat) : Self.isRegular(stat) else { throw Self.unsupported }
            if kind == .file {
                // O_EVTONLY permet l’ancrage des réouvertures au même nom, sans lire/lister le parent.
                let fd = Darwin.open(root.deletingLastPathComponent().path, O_EVTONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
                if fd >= 0 { parent = fd }
            }
            var grant = AccessGrant(selectedURL: selected, kind: kind, resolvedRoot: root)
            grant.usageCount = 1
            entries[grant.id] = Entry(grant: grant, descriptor: descriptor, parentDescriptor: parent)
            return grant
        } catch {
            Darwin.close(descriptor)
            if let parent { Darwin.close(parent) }
            throw error
        }
    }

    func retain(_ id: UUID) throws {
        guard var entry = entries[id], entry.grant.state == .active else { throw Self.denied }
        entry.grant.usageCount += 1
        entries[id] = entry
    }

    @discardableResult
    func release(_ id: UUID) -> Bool {
        guard var entry = entries[id] else { return true }
        entry.grant.usageCount -= 1
        if entry.grant.usageCount > 0 { entries[id] = entry; return false }
        entries.removeValue(forKey: id)
        Darwin.close(entry.descriptor)
        if let parent = entry.parentDescriptor { Darwin.close(parent) }
        return true
    }

    func handle(for url: URL, grantID: UUID) throws -> DocumentHandle {
        let fd = try openAuthorized(url, grantID: grantID)
        defer { Darwin.close(fd) }
        let info = try Self.stat(fd)
        guard Self.isRegular(info) else { throw Self.unsupported }
        return DocumentHandle(location: url.standardizedFileURL, identity: Self.metadata(info).identity, grantID: grantID)
    }

    func metadata(_ url: URL, grantID: UUID) throws -> FileMetadata {
        let fd = try openAuthorized(url, grantID: grantID)
        defer { Darwin.close(fd) }
        let info = try Self.stat(fd)
        guard Self.isRegular(info) else { throw Self.unsupported }
        return Self.metadata(info)
    }

    func observationDescriptors(_ url: URL, grantID: UUID) throws -> [Int32] {
        let fd = try openAuthorized(url, grantID: grantID)
        do { guard Self.isRegular(try Self.stat(fd)) else { throw Self.unsupported } }
        catch { Darwin.close(fd); throw error }
        var descriptors = [fd]
        // Aucune surveillance du parent d’un fichier sélectionné seul.
        if entries[grantID]?.grant.kind == .directory,
           let parent = try? openAuthorized(url.deletingLastPathComponent(), grantID: grantID, directory: true) { descriptors.append(parent) }
        return descriptors
    }

    func read(_ url: URL, grantID: UUID, maximumBytes: Int) throws -> AuthorizedRead {
        let preflight = try openAuthorized(url, grantID: grantID)
        let regular: Bool
        do { regular = Self.isRegular(try Self.stat(preflight)) }
        catch { Darwin.close(preflight); throw error }
        Darwin.close(preflight)
        // Foundation peut attendre un écrivain sur un tube : refuser les fichiers
        // spéciaux avant de demander une coordination, puis revalider dans l’accès.
        guard regular else { throw Self.unsupported }
        var coordinatedError: NSError?
        var result: Result<AuthorizedRead, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinatedError) { _ in
            result = Result { try readDescriptor(url, grantID: grantID, maximumBytes: maximumBytes) }
        }
        if coordinatedError != nil { throw Self.denied }
        guard let result else { throw Self.denied }
        return try result.get()
    }

    private func readDescriptor(_ url: URL, grantID: UUID, maximumBytes: Int) throws -> AuthorizedRead {
        guard maximumBytes >= 0, maximumBytes <= 64 * 1_024 * 1_024 else { throw Self.unsupported }
        let fd = try openAuthorized(url, grantID: grantID)
        defer { Darwin.close(fd) }
        let beforeStat = try Self.stat(fd)
        guard Self.isRegular(beforeStat) else { throw Self.unsupported }
        let before = Self.metadata(beforeStat)
        guard before.byteCount <= UInt64(maximumBytes) else { throw ReaderFailure.documentTooLarge(nil) }
        var bytes = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
        while bytes.count <= maximumBytes {
            try Task.checkCancellation()
            let requested = min(buffer.count, maximumBytes + 1 - bytes.count)
            let count = Darwin.read(fd, &buffer, requested)
            if count == 0 { break }
            if count < 0 {
                if errno == EINTR { continue }
                throw Self.failure(errno)
            }
            bytes.append(contentsOf: buffer.prefix(count))
        }
        guard bytes.count <= maximumBytes else { throw ReaderFailure.documentTooLarge(nil) }
        let after = Self.metadata(try Self.stat(fd))
        guard before == after, after.byteCount == UInt64(bytes.count) else { throw ReaderFailure.unstableRead(nil) }
        // Une substitution du nom pendant la lecture n’est pas publiée comme sa nouvelle version.
        let currentFD = try openAuthorized(url, grantID: grantID)
        defer { Darwin.close(currentFD) }
        guard Self.metadata(try Self.stat(currentFD)) == after else { throw ReaderFailure.unstableRead(nil) }
        return AuthorizedRead(bytes: bytes, before: before, after: after)
    }

    func listDirectory(_ url: URL, grantID: UUID) throws -> [AuthorizedDirectoryItem] {
        guard entries[grantID]?.grant.kind == .directory else { throw Self.denied }
        let fd = try openAuthorized(url, grantID: grantID, directory: true)
        guard let dir = fdopendir(fd) else { Darwin.close(fd); throw Self.failure(errno) }
        defer { closedir(dir) }
        var results: [AuthorizedDirectoryItem] = []
        while let item = readdir(dir) {
            try Task.checkCancellation()
            let name = withUnsafePointer(to: item.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(item.pointee.d_namlen) + 1) { String(cString: $0) }
            }
            guard name != ".", name != "..", !name.hasPrefix(".") else { continue }
            var info = Darwin.stat()
            guard fstatat(fd, name, &info, AT_SYMLINK_NOFOLLOW) == 0 else { continue }
            let directory = Self.isDirectory(info)
            guard directory || (Self.isRegular(info) && ["md", "markdown"].contains(URL(fileURLWithPath: name).pathExtension.lowercased())) else { continue }
            results.append(AuthorizedDirectoryItem(url: url.appendingPathComponent(name, isDirectory: directory), identity: Self.metadata(info).identity, isDirectory: directory))
        }
        return results.sorted { $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending }
    }

    private func openAuthorized(_ url: URL, grantID: UUID, directory: Bool = false) throws -> Int32 {
        guard let entry = entries[grantID], entry.grant.state == .active, url.isFileURL,
              url.query == nil, url.fragment == nil else { throw Self.denied }
        let target = url.standardizedFileURL
        let root = entry.grant.resolvedRoot
        var rootInfo = Darwin.stat()
        guard lstat(root.path, &rootInfo) == 0 else { throw Self.failure(errno) }
        guard (rootInfo.st_mode & S_IFMT) != S_IFLNK else { throw Self.denied }
        if entry.grant.kind == .file {
            guard !directory, target.pathComponents == root.pathComponents else { throw Self.denied }
            if let parent = entry.parentDescriptor {
                var currentParent = Darwin.stat()
                guard lstat(root.deletingLastPathComponent().path, &currentParent) == 0,
                      Self.metadata(currentParent).identity == Self.metadata(try Self.stat(parent)).identity else { throw Self.denied }
                let fd = openat(parent, root.lastPathComponent, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
                guard fd >= 0 else { throw Self.failure(errno) }
                return fd
            }
            guard Self.metadata(rootInfo).identity == Self.metadata(try Self.stat(entry.descriptor)).identity else { throw Self.denied }
            let fd = dup(entry.descriptor)
            guard fd >= 0 else { throw Self.failure(errno) }
            _ = lseek(fd, 0, SEEK_SET)
            return fd
        }
        let rootParts = root.pathComponents
        let parts = target.pathComponents
        guard parts.starts(with: rootParts), Self.metadata(rootInfo).identity == Self.metadata(try Self.stat(entry.descriptor)).identity else { throw Self.denied }
        // dup partagerait l’offset du répertoire et rendrait le second readdir vide.
        // Une nouvelle description ouverte relativement à la racine ancrée repart du début.
        var current = openat(entry.descriptor, ".", O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard current >= 0 else { throw Self.failure(errno) }
        do {
            let descendants = Array(parts.dropFirst(rootParts.count))
            for (index, part) in descendants.enumerated() {
                guard part != ".", part != "..", !part.isEmpty else { throw Self.denied }
                let mustBeDirectory = index < descendants.count - 1 || directory
                let next = openat(current, part, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK | (mustBeDirectory ? O_DIRECTORY : 0))
                guard next >= 0 else { throw Self.failure(errno) }
                Darwin.close(current)
                current = next
            }
            return current
        } catch { Darwin.close(current); throw error }
    }

    private static func stat(_ fd: Int32) throws -> Darwin.stat {
        var info = Darwin.stat()
        guard fstat(fd, &info) == 0 else { throw failure(errno) }
        return info
    }
    private static func isRegular(_ info: Darwin.stat) -> Bool { (info.st_mode & S_IFMT) == S_IFREG }
    private static func isDirectory(_ info: Darwin.stat) -> Bool { (info.st_mode & S_IFMT) == S_IFDIR }
    private static func metadata(_ info: Darwin.stat) -> FileMetadata {
        FileMetadata(identity: FileIdentity(device: UInt64(UInt32(bitPattern: info.st_dev)), inode: UInt64(info.st_ino)), byteCount: UInt64(max(0, info.st_size)), modificationTime: Date(timeIntervalSince1970: Double(info.st_mtimespec.tv_sec) + Double(info.st_mtimespec.tv_nsec) / 1e9), changeTime: Date(timeIntervalSince1970: Double(info.st_ctimespec.tv_sec) + Double(info.st_ctimespec.tv_nsec) / 1e9))
    }
    static let denied = ReaderFailure(category: .accessDenied, message: "Ce fichier n’est pas autorisé. Sélectionnez-le ou choisissez son dossier.", recoveries: [.selectFile, .selectFolder, .close], documentID: nil)
    static let unsupported = ReaderFailure(category: .unsupportedType, message: "Ce fichier n’est pas un document texte pris en charge.", recoveries: [.selectFile, .close], documentID: nil)
    private static func failure(_ code: Int32) -> ReaderFailure {
        if code == ENOENT { return ReaderFailure(category: .missing, message: "Le fichier est introuvable.", recoveries: [.retry, .selectFile, .close], documentID: nil) }
        return denied
    }
}
