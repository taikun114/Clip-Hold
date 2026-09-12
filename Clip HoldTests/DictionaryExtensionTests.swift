import Testing
import Foundation
@testable import Clip_Hold

struct DictionaryExtensionTests {
    
    @Test
    func testMapKeysWithUUIDToString() {
        let uuid1 = UUID()
        let uuid2 = UUID()
        let sourceDict: [UUID: [String]] = [
            uuid1: ["com.apple.Safari", "com.apple.Notes"],
            uuid2: ["com.apple.dt.Xcode"]
        ]
        
        // UUIDキーをStringキーに変換
        let mappedDict = sourceDict.mapKeys { $0.uuidString }
        
        #expect(mappedDict.count == 2)
        #expect(mappedDict[uuid1.uuidString] == ["com.apple.Safari", "com.apple.Notes"])
        #expect(mappedDict[uuid2.uuidString] == ["com.apple.dt.Xcode"])
    }
    
    @Test
    func testMapKeysWithEmptyDictionary() {
        let emptyDict: [String: Int] = [:]
        let mappedDict = emptyDict.mapKeys { $0.uppercased() }
        
        #expect(mappedDict.isEmpty)
    }
    
    @Test
    func testMapKeysTransform() {
        let intKeyDict: [Int: String] = [
            1: "one",
            2: "two",
            3: "three"
        ]
        let stringKeyDict = intKeyDict.mapKeys { "key_\($0)" }
        
        #expect(stringKeyDict["key_1"] == "one")
        #expect(stringKeyDict["key_2"] == "two")
        #expect(stringKeyDict["key_3"] == "three")
    }
}
