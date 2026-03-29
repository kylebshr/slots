import Slots
import SwiftUI
import XCTest

// MARK: - Test components

@Slots
struct Badge<Label: View>: View {
    @Slot(.text) var label: Label?
    var body: some View { EmptyView() }
}

@Slots
struct Card<Title: View, Actions: View>: View {
    @Slot(.text) var title: Title
    var actions: Actions?
    var body: some View { EmptyView() }
}

@Slots
struct Row<Leading: View, Content: View, Trailing: View>: View {
    var isSelected: Bool
    @Slot(.image) var leading: Leading?
    @Slot(.text) var content: Content
    var trailing: Trailing?
    var body: some View { EmptyView() }
}

// MARK: - Integration tests
//
// These tests verify the macro-generated inits actually compile and produce
// the correct concrete types. No assertions needed — a compile error IS the failure.

@MainActor
final class SlotIntegrationTests: XCTestCase {

    // MARK: Badge — single slot, all option combos

    func testBadgeSingleSlot() {
        // generic View (ViewBuilder closure)
        let _: Badge<Text> = Badge { Text("hi") }
        // LocalizedStringKey → Label == Text
        let _: Badge<Text> = Badge(label: "hello")
        // String (disfavored) → Label == Text
        let _: Badge<Text> = Badge(label: "hello" as String)
        // omitted → Label == Never
        let _: Badge<Never> = Badge()
    }

    // MARK: Card — two slots

    func testCardTwoSlots() {
        // all generic (ViewBuilder closures)
        let _: Card<Text, Button<Text>> = Card {
            Text("hi")
        } actions: {
            Button("OK") {}
        }
        // LocalizedStringKey title, generic actions
        let _: Card<Text, Button<Text>> = Card(title: "hi", actions: { Button("OK") {} })
        // String title (disfavored), generic actions
        let _: Card<Text, Button<Text>> = Card(title: "hi" as String, actions: { Button("OK") {} })
        // generic title, no actions → Actions == Never
        let _: Card<Text, Never> = Card { Text("hi") }
        // LocalizedStringKey title, no actions
        let _: Card<Text, Never> = Card(title: "hi")
        // String title (disfavored), no actions
        let _: Card<Text, Never> = Card(title: "hi" as String)
    }

    // MARK: Row — three slots + plain property

    func testRowThreeSlots() {
        // all generic (ViewBuilder closures)
        let _: Row<Image, Text, Text> = Row(
            isSelected: false, leading: { Image(systemName: "star") }, content: { Text("hi") }, trailing: { Text("→") })
        // LocalizedStringKey content, generic leading + trailing
        let _: Row<Image, Text, Text> = Row(
            isSelected: true, content: "hi", leading: { Image(systemName: "star") }, trailing: { Text("→") })
        // image leading, LocalizedStringKey content, generic trailing
        let _: Row<Image, Text, Text> = Row(
            isSelected: false, leadingSystemName: "star", content: "hi", trailing: { Text("→") })
        // image leading, LocalizedStringKey content, no trailing
        let _: Row<Image, Text, Never> = Row(isSelected: false, leadingSystemName: "star", content: "hi")
        // no leading, LocalizedStringKey content, generic trailing
        let _: Row<Never, Text, Text> = Row(isSelected: false, content: "hi", trailing: { Text("→") })
        // no leading, LocalizedStringKey content, no trailing
        let _: Row<Never, Text, Never> = Row(isSelected: false, content: "hi")
        // no leading, no trailing, generic content
        let _: Row<Never, Text, Never> = Row(isSelected: false) { Text("hi") }
    }
}
