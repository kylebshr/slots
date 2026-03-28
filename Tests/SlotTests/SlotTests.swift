import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import SlotMacros

@MainActor
final class SlotTests: XCTestCase {

    // MARK: - Single slot tests

    func testSingleSlotText() {
        let testMacros: [String: Macro.Type] = ["Slotted": SlotMacro.self, "Slot": SlotPropertyMacro.self]
        assertMacroExpansion(
            """
            @Slotted
            struct Badge<Label: View>: View {
                @Slot(.text) var label: Label
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
            struct Badge<Label: View>: View {
                var label: Label
                var body: some View { EmptyView() }

                init(label: Label) {
                    self.label = label
                }
            }

            extension Badge where Label == Text {
                init(label: LocalizedStringKey) {
                    self.label = Text(label)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testSingleSlotOptional() {
        let testMacros: [String: Macro.Type] = ["Slotted": SlotMacro.self, "Slot": SlotPropertyMacro.self]
        assertMacroExpansion(
            """
            @Slotted
            struct Row<Icon: View>: View {
                @Slot(.optional) var icon: Icon
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
            struct Row<Icon: View>: View {
                var icon: Icon
                var body: some View { EmptyView() }

                init(icon: Icon) {
                    self.icon = icon
                }
            }

            extension Row where Icon == EmptyView {
                init() {
                    self.icon = EmptyView()
                }
            }
            """,
            macros: testMacros
        )
    }

    func testSingleSlotString() {
        let testMacros: [String: Macro.Type] = ["Slotted": SlotMacro.self, "Slot": SlotPropertyMacro.self]
        assertMacroExpansion(
            """
            @Slotted
            struct Badge<Label: View>: View {
                @Slot(.string) var label: Label
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
            struct Badge<Label: View>: View {
                var label: Label
                var body: some View { EmptyView() }

                init(label: Label) {
                    self.label = label
                }
            }

            extension Badge where Label == Text {
                @_disfavoredOverload
                init(label: String) {
                    self.label = Text(label)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testSingleSlotTextAndString() {
        let testMacros: [String: Macro.Type] = ["Slotted": SlotMacro.self, "Slot": SlotPropertyMacro.self]
        assertMacroExpansion(
            """
            @Slotted
            struct Badge<Label: View>: View {
                @Slot(.text, .string) var label: Label
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
            struct Badge<Label: View>: View {
                var label: Label
                var body: some View { EmptyView() }

                init(label: Label) {
                    self.label = label
                }
            }

            extension Badge where Label == Text {
                init(label: LocalizedStringKey) {
                    self.label = Text(label)
                }

                @_disfavoredOverload
                init(label: String) {
                    self.label = Text(label)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testSingleSlotTextOptionalAndString() {
        let testMacros: [String: Macro.Type] = ["Slotted": SlotMacro.self, "Slot": SlotPropertyMacro.self]
        assertMacroExpansion(
            """
            @Slotted
            struct Badge<Label: View>: View {
                @Slot(.text, .string, .optional) var label: Label
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
            struct Badge<Label: View>: View {
                var label: Label
                var body: some View { EmptyView() }

                init(label: Label) {
                    self.label = label
                }
            }

            extension Badge where Label == Text {
                init(label: LocalizedStringKey) {
                    self.label = Text(label)
                }

                @_disfavoredOverload
                init(label: String) {
                    self.label = Text(label)
                }
            }

            extension Badge where Label == EmptyView {
                init() {
                    self.label = EmptyView()
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Two slot tests

    func testTwoSlotsTextAndOptional() {
        let testMacros: [String: Macro.Type] = ["Slotted": SlotMacro.self, "Slot": SlotPropertyMacro.self]
        assertMacroExpansion(
            """
            @Slotted
            struct Card<Title: View, Actions: View>: View {
                @Slot(.text) var title: Title
                @Slot(.optional) var actions: Actions
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
            struct Card<Title: View, Actions: View>: View {
                var title: Title
                var actions: Actions
                var body: some View { EmptyView() }

                init(title: Title, actions: Actions) {
                    self.title = title
                    self.actions = actions
                }
            }

            extension Card where Actions == EmptyView {
                init(title: Title) {
                    self.title = title
                    self.actions = EmptyView()
                }
            }

            extension Card where Title == Text {
                init(title: LocalizedStringKey, actions: Actions) {
                    self.title = Text(title)
                    self.actions = actions
                }
            }

            extension Card where Title == Text, Actions == EmptyView {
                init(title: LocalizedStringKey) {
                    self.title = Text(title)
                    self.actions = EmptyView()
                }
            }
            """,
            macros: testMacros
        )
    }

    func testTwoSlotsWithString() {
        let testMacros: [String: Macro.Type] = ["Slotted": SlotMacro.self, "Slot": SlotPropertyMacro.self]
        assertMacroExpansion(
            """
            @Slotted
            struct Card<Title: View, Footer: View>: View {
                @Slot(.text, .string) var title: Title
                @Slot(.optional) var footer: Footer
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
            struct Card<Title: View, Footer: View>: View {
                var title: Title
                var footer: Footer
                var body: some View { EmptyView() }

                init(title: Title, footer: Footer) {
                    self.title = title
                    self.footer = footer
                }
            }

            extension Card where Footer == EmptyView {
                init(title: Title) {
                    self.title = title
                    self.footer = EmptyView()
                }
            }

            extension Card where Title == Text {
                init(title: LocalizedStringKey, footer: Footer) {
                    self.title = Text(title)
                    self.footer = footer
                }

                @_disfavoredOverload
                init(title: String, footer: Footer) {
                    self.title = Text(title)
                    self.footer = footer
                }
            }

            extension Card where Title == Text, Footer == EmptyView {
                init(title: LocalizedStringKey) {
                    self.title = Text(title)
                    self.footer = EmptyView()
                }

                @_disfavoredOverload
                init(title: String) {
                    self.title = Text(title)
                    self.footer = EmptyView()
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Three slot test

    func testThreeSlots() {
        let testMacros: [String: Macro.Type] = ["Slotted": SlotMacro.self, "Slot": SlotPropertyMacro.self]
        assertMacroExpansion(
            """
            @Slotted
            struct Card<Title: View, Subtitle: View, Actions: View>: View {
                @Slot(.text) var title: Title
                @Slot(.text) var subtitle: Subtitle
                @Slot(.optional) var actions: Actions
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
            struct Card<Title: View, Subtitle: View, Actions: View>: View {
                var title: Title
                var subtitle: Subtitle
                var actions: Actions
                var body: some View { EmptyView() }

                init(title: Title, subtitle: Subtitle, actions: Actions) {
                    self.title = title
                    self.subtitle = subtitle
                    self.actions = actions
                }
            }

            extension Card where Actions == EmptyView {
                init(title: Title, subtitle: Subtitle) {
                    self.title = title
                    self.subtitle = subtitle
                    self.actions = EmptyView()
                }
            }

            extension Card where Subtitle == Text {
                init(title: Title, subtitle: LocalizedStringKey, actions: Actions) {
                    self.title = title
                    self.subtitle = Text(subtitle)
                    self.actions = actions
                }
            }

            extension Card where Subtitle == Text, Actions == EmptyView {
                init(title: Title, subtitle: LocalizedStringKey) {
                    self.title = title
                    self.subtitle = Text(subtitle)
                    self.actions = EmptyView()
                }
            }

            extension Card where Title == Text {
                init(title: LocalizedStringKey, subtitle: Subtitle, actions: Actions) {
                    self.title = Text(title)
                    self.subtitle = subtitle
                    self.actions = actions
                }
            }

            extension Card where Title == Text, Actions == EmptyView {
                init(title: LocalizedStringKey, subtitle: Subtitle) {
                    self.title = Text(title)
                    self.subtitle = subtitle
                    self.actions = EmptyView()
                }
            }

            extension Card where Title == Text, Subtitle == Text {
                init(title: LocalizedStringKey, subtitle: LocalizedStringKey, actions: Actions) {
                    self.title = Text(title)
                    self.subtitle = Text(subtitle)
                    self.actions = actions
                }
            }

            extension Card where Title == Text, Subtitle == Text, Actions == EmptyView {
                init(title: LocalizedStringKey, subtitle: LocalizedStringKey) {
                    self.title = Text(title)
                    self.subtitle = Text(subtitle)
                    self.actions = EmptyView()
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Four slot test

    func testFourSlots() {
        let testMacros: [String: Macro.Type] = ["Slotted": SlotMacro.self, "Slot": SlotPropertyMacro.self]
        assertMacroExpansion(
            """
            @Slotted
            struct Card<Title: View, Subtitle: View, Body: View, Footer: View>: View {
                @Slot(.text) var title: Title
                @Slot(.optional) var subtitle: Subtitle
                @Slot(.text) var body_: Body
                @Slot(.optional) var footer: Footer
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
            struct Card<Title: View, Subtitle: View, Body: View, Footer: View>: View {
                var title: Title
                var subtitle: Subtitle
                var body_: Body
                var footer: Footer
                var body: some View { EmptyView() }

                init(title: Title, subtitle: Subtitle, body_: Body, footer: Footer) {
                    self.title = title
                    self.subtitle = subtitle
                    self.body_ = body_
                    self.footer = footer
                }
            }

            extension Card where Footer == EmptyView {
                init(title: Title, subtitle: Subtitle, body_: Body) {
                    self.title = title
                    self.subtitle = subtitle
                    self.body_ = body_
                    self.footer = EmptyView()
                }
            }

            extension Card where Body == Text {
                init(title: Title, subtitle: Subtitle, body_: LocalizedStringKey, footer: Footer) {
                    self.title = title
                    self.subtitle = subtitle
                    self.body_ = Text(body_)
                    self.footer = footer
                }
            }

            extension Card where Body == Text, Footer == EmptyView {
                init(title: Title, subtitle: Subtitle, body_: LocalizedStringKey) {
                    self.title = title
                    self.subtitle = subtitle
                    self.body_ = Text(body_)
                    self.footer = EmptyView()
                }
            }

            extension Card where Subtitle == EmptyView {
                init(title: Title, body_: Body, footer: Footer) {
                    self.title = title
                    self.subtitle = EmptyView()
                    self.body_ = body_
                    self.footer = footer
                }
            }

            extension Card where Subtitle == EmptyView, Footer == EmptyView {
                init(title: Title, body_: Body) {
                    self.title = title
                    self.subtitle = EmptyView()
                    self.body_ = body_
                    self.footer = EmptyView()
                }
            }

            extension Card where Subtitle == EmptyView, Body == Text {
                init(title: Title, body_: LocalizedStringKey, footer: Footer) {
                    self.title = title
                    self.subtitle = EmptyView()
                    self.body_ = Text(body_)
                    self.footer = footer
                }
            }

            extension Card where Subtitle == EmptyView, Body == Text, Footer == EmptyView {
                init(title: Title, body_: LocalizedStringKey) {
                    self.title = title
                    self.subtitle = EmptyView()
                    self.body_ = Text(body_)
                    self.footer = EmptyView()
                }
            }

            extension Card where Title == Text {
                init(title: LocalizedStringKey, subtitle: Subtitle, body_: Body, footer: Footer) {
                    self.title = Text(title)
                    self.subtitle = subtitle
                    self.body_ = body_
                    self.footer = footer
                }
            }

            extension Card where Title == Text, Footer == EmptyView {
                init(title: LocalizedStringKey, subtitle: Subtitle, body_: Body) {
                    self.title = Text(title)
                    self.subtitle = subtitle
                    self.body_ = body_
                    self.footer = EmptyView()
                }
            }

            extension Card where Title == Text, Body == Text {
                init(title: LocalizedStringKey, subtitle: Subtitle, body_: LocalizedStringKey, footer: Footer) {
                    self.title = Text(title)
                    self.subtitle = subtitle
                    self.body_ = Text(body_)
                    self.footer = footer
                }
            }

            extension Card where Title == Text, Body == Text, Footer == EmptyView {
                init(title: LocalizedStringKey, subtitle: Subtitle, body_: LocalizedStringKey) {
                    self.title = Text(title)
                    self.subtitle = subtitle
                    self.body_ = Text(body_)
                    self.footer = EmptyView()
                }
            }

            extension Card where Title == Text, Subtitle == EmptyView {
                init(title: LocalizedStringKey, body_: Body, footer: Footer) {
                    self.title = Text(title)
                    self.subtitle = EmptyView()
                    self.body_ = body_
                    self.footer = footer
                }
            }

            extension Card where Title == Text, Subtitle == EmptyView, Footer == EmptyView {
                init(title: LocalizedStringKey, body_: Body) {
                    self.title = Text(title)
                    self.subtitle = EmptyView()
                    self.body_ = body_
                    self.footer = EmptyView()
                }
            }

            extension Card where Title == Text, Subtitle == EmptyView, Body == Text {
                init(title: LocalizedStringKey, body_: LocalizedStringKey, footer: Footer) {
                    self.title = Text(title)
                    self.subtitle = EmptyView()
                    self.body_ = Text(body_)
                    self.footer = footer
                }
            }

            extension Card where Title == Text, Subtitle == EmptyView, Body == Text, Footer == EmptyView {
                init(title: LocalizedStringKey, body_: LocalizedStringKey) {
                    self.title = Text(title)
                    self.subtitle = EmptyView()
                    self.body_ = Text(body_)
                    self.footer = EmptyView()
                }
            }
            """,
            macros: testMacros
        )
    }
    // Plain stored properties WITH a default value are omitted from all generated inits.
    func testPlainPropertyWithDefault() {
        let testMacros: [String: Macro.Type] = ["Slotted": SlotMacro.self, "Slot": SlotPropertyMacro.self]
        assertMacroExpansion(
            """
            @Slotted
            struct Badge<Label: View>: View {
                var count: Int = 0
                @Slot(.text) var label: Label
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
            struct Badge<Label: View>: View {
                var count: Int = 0
                var label: Label
                var body: some View { EmptyView() }

                init(label: Label) {
                    self.label = label
                }
            }

            extension Badge where Label == Text {
                init(label: LocalizedStringKey) {
                    self.label = Text(label)
                }
            }
            """,
            macros: testMacros
        )
    }

    // Plain stored properties WITHOUT a default value must appear as labeled
    // parameters in every generated init — base and all constrained extensions.
    func testPlainPropertyWithoutDefault() {
        let testMacros: [String: Macro.Type] = ["Slotted": SlotMacro.self, "Slot": SlotPropertyMacro.self]
        assertMacroExpansion(
            """
            @Slotted
            struct Banner<Icon: View, Label: View>: View {
                var isEnabled: Bool
                var badge: Int = 0
                @Slot(.optional) var icon: Icon
                @Slot(.text) var label: Label
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
            struct Banner<Icon: View, Label: View>: View {
                var isEnabled: Bool
                var badge: Int = 0
                var icon: Icon
                var label: Label
                var body: some View { EmptyView() }

                init(isEnabled: Bool, icon: Icon, label: Label) {
                    self.isEnabled = isEnabled
                    self.icon = icon
                    self.label = label
                }
            }

            extension Banner where Label == Text {
                init(isEnabled: Bool, icon: Icon, label: LocalizedStringKey) {
                    self.isEnabled = isEnabled
                    self.icon = icon
                    self.label = Text(label)
                }
            }

            extension Banner where Icon == EmptyView {
                init(isEnabled: Bool, label: Label) {
                    self.isEnabled = isEnabled
                    self.icon = EmptyView()
                    self.label = label
                }
            }

            extension Banner where Icon == EmptyView, Label == Text {
                init(isEnabled: Bool, label: LocalizedStringKey) {
                    self.isEnabled = isEnabled
                    self.icon = EmptyView()
                    self.label = Text(label)
                }
            }
            """,
            macros: testMacros
        )
    }

}
