import Slots
import SwiftUI
import XCTest

// MARK: - Resolver

enum Priority: String, Sendable { case low, medium, high }

struct PriorityBadge: View {
    let priority: Priority
    var body: some View { Text(priority.rawValue) }
}

enum PriorityResolver: SlotResolver {
    typealias Input = Priority
    typealias Output = PriorityBadge
    static func resolve(_ input: Priority) -> PriorityBadge {
        PriorityBadge(priority: input)
    }
}

// MARK: - Test components

@Slots
struct TaskRow<Title: View, Badge: View>: View {
    @Slot(.text) var title: Title
    @Slot(PriorityResolver.self) var badge: Badge?
    var body: some View { EmptyView() }
}

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
    @Slot(.systemImage) var leading: Leading?
    @Slot(.text) var content: Content
    var trailing: Trailing?
    var body: some View { EmptyView() }
}

@Slots
struct IdentifiedRow<ID: Hashable, Label: View>: View {
    var id: ID
    var parentID: ID?
    @Slot(.text) var label: Label
    var body: some View { EmptyView() }
}

@Slots
struct GenericPicker<Value: Hashable, Label: View, Icon: View>: View {
    @Binding var selection: Value
    @Binding var highlighted: Value?
    @Binding var icon: Icon?
    @Slot(.text) var label: Label
    var body: some View { EmptyView() }
}

@Slots
struct BuilderRow<Content: View, Label: View>: View {
    @ViewBuilder var content: () -> Content
    @Slot(.text) var label: Label
    var body: some View { EmptyView() }
}

@Slots
struct ConstantRow<Label: View, Icon: View>: View {
    let spacing: Double = 8
    let icon: Icon? = nil
    @Slot(.text) var label: Label
    var body: some View { EmptyView() }
}

@Slots
struct WhereClauseRow<Label, Icon>: View where Label: View, Icon: View {
    @Slot(.text) var label: Label
    var icon: Icon?
    var body: some View { EmptyView() }
}

@Slots
private struct PrivateRow<Label: View>: View {
    @Slot(.text) var label: Label
    var body: some View { EmptyView() }
}

@Slots
struct ScopedLabelRow<Badge: View>: View {
    @Slot(.text) @Slot(PriorityResolver.self, .unlabeled) var badge: Badge
    var body: some View { EmptyView() }
}

struct InternalStyle {
    var spacing: Double
}

@Slots(.internalInit)
public struct InternalInitRow<Label: View>: View {
    var style: InternalStyle
    @Slot(.text) var label: Label
    public var body: some View { EmptyView() }
}

// MARK: - Integration tests
//
// These tests verify the macro-generated inits actually compile and produce
// the correct concrete types. No assertions needed — a compile error IS the failure.

@MainActor
final class SlotIntegrationTests: XCTestCase {

    // MARK: TaskRow — resolver slot (optional)

    func testTaskRowResolver() {
        // resolver input: Priority → PriorityBadge
        let _: TaskRow<Text, PriorityBadge> = TaskRow(title: "Buy groceries", badge: .high)
        // generic badge slot
        let _: TaskRow<Text, Text> = TaskRow(title: "Meeting") { Text("Important") }
        // no badge → Badge == Never
        let _: TaskRow<Text, Never> = TaskRow(title: "No priority")
        // String title (disfavored), resolver badge
        let _: TaskRow<Text, PriorityBadge> = TaskRow(title: "Task" as String, badge: .low)
        // both generic
        let _: TaskRow<Text, Text> = TaskRow {
            Text("Party")
        } badge: {
            Text("Custom")
        }
    }

    // MARK: Badge — single slot, all option combos

    func testBadgeSingleSlot() {
        // generic View (ViewBuilder closure)
        let _: Badge<Text> = Badge { Text("hi") }
        // LocalizedStringResource → Label == Text
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
        // LocalizedStringResource title, generic actions
        let _: Card<Text, Button<Text>> = Card(title: "hi", actions: { Button("OK") {} })
        // String title (disfavored), generic actions
        let _: Card<Text, Button<Text>> = Card(title: "hi" as String, actions: { Button("OK") {} })
        // generic title, no actions → Actions == Never
        let _: Card<Text, Never> = Card { Text("hi") }
        // LocalizedStringResource title, no actions
        let _: Card<Text, Never> = Card(title: "hi")
        // String title (disfavored), no actions
        let _: Card<Text, Never> = Card(title: "hi" as String)
    }

    // MARK: Row — three slots + plain property

    func testRowThreeSlots() {
        // all generic (ViewBuilder closures)
        let _: Row<Image, Text, Text> = Row(
            isSelected: false, leading: { Image(systemName: "star") }, content: { Text("hi") }, trailing: { Text("→") })
        // LocalizedStringResource content, generic leading + trailing
        let _: Row<Image, Text, Text> = Row(
            isSelected: true, content: "hi", leading: { Image(systemName: "star") }, trailing: { Text("→") })
        // image leading, LocalizedStringResource content, generic trailing
        let _: Row<Image, Text, Text> = Row(
            isSelected: false, leadingSystemName: "star", content: "hi", trailing: { Text("→") })
        // image leading, LocalizedStringResource content, no trailing
        let _: Row<Image, Text, Never> = Row(isSelected: false, leadingSystemName: "star", content: "hi")
        // no leading, LocalizedStringResource content, generic trailing
        let _: Row<Never, Text, Text> = Row(isSelected: false, content: "hi", trailing: { Text("→") })
        // no leading, LocalizedStringResource content, no trailing
        let _: Row<Never, Text, Never> = Row(isSelected: false, content: "hi")
        // no leading, no trailing, generic content
        let _: Row<Never, Text, Never> = Row(isSelected: false) { Text("hi") }
    }

    // MARK: Generic parameters that aren't views are plain properties

    func testNonViewGenericParameters() {
        let _: IdentifiedRow<Int, Text> = IdentifiedRow(id: 1, label: "hi")
        let _: IdentifiedRow<Int, Text> = IdentifiedRow(id: 1, parentID: 2, label: "hi")
    }

    // MARK: Bindings to generic and optional values

    func testGenericAndOptionalBindings() {
        let _: GenericPicker<Int, Text, Image> = GenericPicker(
            selection: .constant(1), highlighted: .constant(nil), icon: .constant(nil), label: "hi")
    }

    // MARK: @ViewBuilder closure properties keep @ViewBuilder

    func testViewBuilderClosureProperty() {
        let _: BuilderRow<TupleView<(Text, Text)>, Text> = BuilderRow(label: "hi") {
            Text("a")
            Text("b")
        }
    }

    // MARK: Initialized constants are excluded

    func testInitializedConstantsExcluded() {
        let _: ConstantRow<Text, Image> = ConstantRow(label: "hi")
    }

    // MARK: View constraints in a where clause

    func testWhereClauseConstraints() {
        let _: WhereClauseRow<Text, Never> = WhereClauseRow(label: "hi")
        let _: WhereClauseRow<Text, Image> = WhereClauseRow(label: "hi") { Image(systemName: "star") }
    }

    // MARK: Private structs are usable from the rest of the file

    func testPrivateStruct() {
        let _: PrivateRow<Text> = PrivateRow(label: "hi")
    }

    // MARK: Each @Slot attribute labels only its own variants

    func testScopedUnlabeled() {
        let _: ScopedLabelRow<Text> = ScopedLabelRow(badge: "hi")
        let _: ScopedLabelRow<PriorityBadge> = ScopedLabelRow(.high)
    }

    // MARK: .internalInit allows internal property types on a public struct

    func testInternalInit() {
        let _: InternalInitRow<Text> = InternalInitRow(style: InternalStyle(spacing: 8), label: "hi")
    }
}
