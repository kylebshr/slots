import SwiftUI

public protocol SlotResolver {
    associatedtype Input
    associatedtype Output: View
    static func makeView(_ input: Input) -> Output
}
