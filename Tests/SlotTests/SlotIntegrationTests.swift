import XCTest
import SwiftUI
import Slot

// MARK: - Test components

@Slotted
struct Badge<Label: View>: View {
    @Slot(.text, .string, .optional) var label: Label
    var body: some View { EmptyView() }
}

@Slotted
struct Card<Title: View, Actions: View>: View {
    @Slot(.text, .string) var title: Title
    @Slot(.optional)      var actions: Actions
    var body: some View { EmptyView() }
}

@Slotted
struct Row<Leading: View, Content: View, Trailing: View>: View {
    var isSelected: Bool
    @Slot(.optional)      var leading: Leading
    @Slot(.text, .string) var content: Content
    @Slot(.optional)      var trailing: Trailing
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
        // generic View
        let _: Badge<Text>  = Badge(label: Text("hi"))
        // LocalizedStringKey → Label == Text
        let _: Badge<Text>  = Badge(label: "hello")
        // String (disfavored) → Label == Text
        let _: Badge<Text>  = Badge(label: "hello" as String)
        // omitted → Label == EmptyView
        let _: Badge<EmptyView> = Badge()
    }

    // MARK: Card — two slots

    func testCardTwoSlots() {
        // all generic
        let _: Card<Text, Button<Text>>       = Card(title: Text("hi"), actions: Button("OK") {})
        // LocalizedStringKey title, generic actions
        let _: Card<Text, Button<Text>>       = Card(title: "hi", actions: Button("OK") {})
        // String title (disfavored), generic actions
        let _: Card<Text, Button<Text>>       = Card(title: "hi" as String, actions: Button("OK") {})
        // generic title, no actions
        let _: Card<Text, EmptyView>          = Card(title: Text("hi"))
        // LocalizedStringKey title, no actions
        let _: Card<Text, EmptyView>          = Card(title: "hi")
        // String title (disfavored), no actions
        let _: Card<Text, EmptyView>          = Card(title: "hi" as String)
    }

    // MARK: Row — three slots + plain property

    func testRowThreeSlots() {
        // all generic
        let _: Row<Image, Text, Text>         = Row(isSelected: false, leading: Image(systemName: "star"), content: Text("hi"), trailing: Text("→"))
        // LocalizedStringKey content, generic leading + trailing
        let _: Row<Image, Text, Text>         = Row(isSelected: true, leading: Image(systemName: "star"), content: "hi", trailing: Text("→"))
        // no leading, LocalizedStringKey content, generic trailing
        let _: Row<EmptyView, Text, Text>     = Row(isSelected: false, content: "hi", trailing: Text("→"))
        // no leading, LocalizedStringKey content, no trailing
        let _: Row<EmptyView, Text, EmptyView> = Row(isSelected: false, content: "hi")
        // no leading, no trailing, generic content
        let _: Row<EmptyView, Text, EmptyView> = Row(isSelected: false, content: Text("hi"))
    }
}
