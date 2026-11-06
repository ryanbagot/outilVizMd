import CryptoKit
import Foundation

struct PerformanceCorpus {
    let corpus: TemporaryCorpus
    init() throws { corpus = try TemporaryCorpus(); try corpus.copyFixtures() }
    func document(mebibytes: Int) throws -> URL {
        let target = mebibytes * 1_024 * 1_024
        let prose = String(repeating: "La lecture locale preserve les documents et permet de retrouver un passage. ", count: 60)
        let block = """
        ## Chapitre de lecture

        \(prose) Une **occurrence rare** se trouve ici.

        - Une liste
        - Une autre entree avec [un lien](#lecture)

        | Nom | Valeur |
        | --- | --- |
        | Lecture | locale |

        ```swift
        let valeur = "lecture"
        ```

        ![Image locale](Images/sample.png)

        """ + "\n"
        var bytes = Data("# Lecture — café\n\n".utf8)
        let chunk = Data(block.utf8)
        while bytes.count + chunk.count <= target { bytes.append(chunk) }
        bytes.append(Data(repeating: 32, count: target - bytes.count))
        return try corpus.write(bytes, to: "performance-\(mebibytes).md")
    }
    func directory() throws -> URL {
        for index in 0..<1_000 { try corpus.write(Data("# Document \(index)".utf8), to: "directory/\(index).md") }
        return try corpus.url("directory")
    }
    func fingerprint(_ url: URL) throws -> [String: String] {
        let bytes = try Data(contentsOf: url)
        return ["name": url.lastPathComponent, "bytes": String(bytes.count), "sha256": SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()]
    }
}
