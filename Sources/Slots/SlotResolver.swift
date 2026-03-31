import SwiftUI

public protocol SlotResolver {
    associatedtype Input
    associatedtype Output: View
    static func resolve(_ input: Input) -> Output
}
