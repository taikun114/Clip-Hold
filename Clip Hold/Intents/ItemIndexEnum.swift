import Foundation
import AppIntents

@available(macOS 14.0, *)
enum ItemIndexEnum: Int, AppEnum {
    case first = 1
    case second = 2
    case third = 3
    case fourth = 4
    case fifth = 5
    case sixth = 6
    case seventh = 7
    case eighth = 8
    case ninth = 9
    case tenth = 10
    
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Item Index"
    static let caseDisplayRepresentations: [ItemIndexEnum: DisplayRepresentation] = [
        .first: DisplayRepresentation(title: "\(1)"),
        .second: DisplayRepresentation(title: "\(2)"),
        .third: DisplayRepresentation(title: "\(3)"),
        .fourth: DisplayRepresentation(title: "\(4)"),
        .fifth: DisplayRepresentation(title: "\(5)"),
        .sixth: DisplayRepresentation(title: "\(6)"),
        .seventh: DisplayRepresentation(title: "\(7)"),
        .eighth: DisplayRepresentation(title: "\(8)"),
        .ninth: DisplayRepresentation(title: "\(9)"),
        .tenth: DisplayRepresentation(title: "\(10)")
    ]
}
