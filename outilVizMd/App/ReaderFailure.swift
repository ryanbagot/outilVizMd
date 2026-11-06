import Foundation

struct ReaderFailure: Error, Equatable, Sendable, LocalizedError {
    enum Category: String, Sendable {
        case accessDenied, accessRevoked, missing, unsupportedType, unsupportedEncoding
        case sizeExceeded, unstableRead, resourceUnavailable, renderingFailed
        case preferencesNotSaved, generationExhausted
    }

    enum Recovery: String, Sendable {
        case selectFile, selectFolder, retry, resetPreferences, close
    }

    let category: Category
    let message: String
    let recoveries: [Recovery]
    let documentID: UUID?

    var errorDescription: String? { message }

    static func documentTooLarge(_ documentID: UUID?) -> Self {
        Self(category: .sizeExceeded, message: "Ce document dépasse la limite de 10 Mio.",
             recoveries: [.selectFile, .close], documentID: documentID)
    }

    static func invalidUTF8(_ documentID: UUID?) -> Self {
        Self(category: .unsupportedEncoding, message: "Ce document n’est pas un texte UTF-8 valide.",
             recoveries: [.selectFile, .close], documentID: documentID)
    }

    static func unstableRead(_ documentID: UUID?) -> Self {
        Self(category: .unstableRead, message: "Le fichier a changé pendant sa lecture. Réessayez.",
             recoveries: [.retry, .close], documentID: documentID)
    }

    static let previewProtectionUnavailable = Self(
        category: .renderingFailed,
        message: "Les protections de l’aperçu n’ont pas pu être installées. Réessayez.",
        recoveries: [.retry, .close], documentID: nil
    )
}
