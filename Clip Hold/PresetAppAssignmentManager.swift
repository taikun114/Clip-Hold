
import Foundation
import SwiftUI
import Combine

@MainActor
class PresetAppAssignmentManager: ObservableObject {
    static let shared = PresetAppAssignmentManager()

    @Published var assignments: [UUID: [String]] = [:] {
        didSet {
            saveAssignments()
        }
    }

    private let userDefaultsKey = "presetAppAssignments"

    private init() {
        loadAssignments()
    }

    func addAssignment(for presetId: UUID, bundleIdentifier: String) {
        if assignments[presetId]?.contains(bundleIdentifier) == false || assignments[presetId] == nil {
            assignments[presetId, default: []].append(bundleIdentifier)
            objectWillChange.send()
        }
    }

    func removeAssignment(for bundleIdentifier: String) {
        for (presetId, _) in assignments {
            assignments[presetId]?.removeAll { $0 == bundleIdentifier }
        }
        objectWillChange.send()
    }
    
    func removeAssignment(for presetId: UUID, bundleIdentifier: String) {
        assignments[presetId]?.removeAll { $0 == bundleIdentifier }
        objectWillChange.send()
    }

    func getAssignments(for presetId: UUID) -> [String] {
        return assignments[presetId] ?? []
    }

    func getPresetId(for bundleIdentifier: String) -> UUID? {
        for (presetId, bundleIds) in assignments {
            if bundleIds.contains(bundleIdentifier) {
                return presetId
            }
        }
        return nil
    }

    func clearAssignments(for presetId: UUID) {
        assignments[presetId] = nil
        objectWillChange.send()
    }

    private func saveAssignments() {
        let encodableAssignments = assignments.mapKeys { $0.uuidString }
        if let encoded = try? JSONEncoder().encode(encodableAssignments) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func loadAssignments() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return
        }
        
        self.assignments = decoded.reduce(into: [UUID: [String]]()) { result, pair in
            if let uuid = UUID(uuidString: pair.key) {
                result[uuid] = pair.value
            }
        }
    }
}

extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        return Dictionary<T, Value>(uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }
}
