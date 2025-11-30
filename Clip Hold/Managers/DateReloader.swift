import Foundation
import Combine

class DateReloader: ObservableObject {
    @Published var now: Date = Date()
    private var timer: AnyCancellable?

    init() {
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
