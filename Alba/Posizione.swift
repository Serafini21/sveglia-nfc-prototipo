import CoreLocation

/// Posizione letta solo con l'app aperta (permesso «Mentre usi l'app»): per impostare la casa e,
/// nell'Emergency Stop, per sapere se sei fuori casa. Niente posizione in background.
enum Posizione {
    /// Segue la posizione finché il task non viene annullato (la schermata si chiude).
    /// `aggiorna` riceve ogni nuova posizione, oppure (nil, true) se il permesso è negato.
    @MainActor
    static func segui(_ aggiorna: (CLLocation?, Bool) -> Void) async {
        let sessione = CLServiceSession(authorization: .whenInUse) // chiede il permesso se serve
        do {
            for try await u in CLLocationUpdate.liveUpdates() {
                if u.authorizationDenied || u.authorizationDeniedGlobally {
                    aggiorna(nil, true)
                } else if let l = u.location {
                    aggiorna(l, false)
                }
            }
        } catch {
            EventLog.scrivi("ERRORE posizione: \(error)")
        }
        withExtendedLifetime(sessione) {}
    }
}
