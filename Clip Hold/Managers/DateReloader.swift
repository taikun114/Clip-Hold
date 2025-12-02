import Foundation
import Combine

class DateReloader: ObservableObject {
    static let shared = DateReloader()

    @Published var now: Date = Date()
    private var timer: AnyCancellable?

    private init() {
        timer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] newDate in
                self?.now = newDate
            }
    }
    
    deinit {
        timer?.cancel()
    }
}
