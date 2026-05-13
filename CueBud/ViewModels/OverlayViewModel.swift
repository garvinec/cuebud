import Foundation
import Combine

@MainActor
final class OverlayViewModel: ObservableObject {
    @Published var activeTips: [CoachingTip] = []

    private var cancellables = Set<AnyCancellable>()
    private let session: SessionViewModel

    init(session: SessionViewModel) {
        self.session = session
        session.tipEngine.$activeTips
            .receive(on: DispatchQueue.main)
            .assign(to: &$activeTips)
    }

    func dismissTip(id: UUID) {
        session.tipEngine.userDismiss(id: id)
    }
}
