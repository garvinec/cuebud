import SwiftUI
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {
    @AppStorage("cuebud.freeSessionsUsed") var freeSessionsUsed: Int = 0
    static let freeSessionLimit = 3

    @Published private(set) var isPro: Bool = false
    private var cancellable: AnyCancellable?

    init(auth: AuthService) {
        isPro = auth.currentUser?.tier == "premium"
        cancellable = auth.$currentUser
            .map { $0?.tier == "premium" }
            .sink { [weak self] value in self?.isPro = value }
    }

    var canStartSession: Bool { isPro || freeSessionsUsed < Self.freeSessionLimit }

    var sessionsRemaining: Int { max(0, Self.freeSessionLimit - freeSessionsUsed) }

    func recordSessionCompleted() {
        guard !isPro else { return }
        freeSessionsUsed = min(freeSessionsUsed + 1, Self.freeSessionLimit)
    }
}
