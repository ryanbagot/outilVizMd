import Foundation

/// Adresse du serveur de contrôle lancé hors du bundle par verify-webkit-network.py.
/// Les tests n’ajoutent aucun serveur ni droit réseau entrant à l’application.
enum NetworkProbe {
    static let endpoint = "http://127.0.0.1:49183"
}
