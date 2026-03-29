import SlotMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@MainActor
final class SlotTests: XCTestCase {

    // MARK: - Single slot tests

    func testSingleSlotText() {
        let testMacros: [String: Macro.Type] = ["Slots": SlotMacro.self, "Slot": SlotPropertyMacro.self]
        assertMacroExpansion(
            """
            @Slots
            struct Badge<Label: View>: View {
                @Slot(.text) var label: Label
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
                struct Badge<Label: View>: View {
                    var label: Label
                    var body: some View { EmptyView() }

                    init(@ViewBuilder label: () -> Label) {
                        self.label = label()
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

    func testSingleSlotOptional() {
        let testMacros: [String: Macro.Type] = ["Slots": SlotMacro.self, "Slot": SlotPropertyMacro.self]
        assertMacroExpansion(
            """
            @Slots
            struct Row<Icon: View>: View {
                var icon: Icon?
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
                struct Row<Icon: View>: View {
                    var icon: Icon?
                    var body: some View { EmptyView() }

                    init(@ViewBuilder icon: () -> Icon) {
                        self.icon = icon()
                    }
                }

                extension Row where Icon == Never {
                    init() {
                        self.icon = nil
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testSingleSlotTextOptional() {
        let testMacros: [String: Macro.Type] = ["Slots": SlotMacro.self, "Slot": SlotPropertyMacro.self]
        assertMacroExpansion(
            """
            @Slots
            struct Badge<Label: View>: View {
                @Slot(.text) var label: Label?
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
                struct Badge<Label: View>: View {
                    var label: Label?
                    var body: some View { EmptyView() }

                    init(@ViewBuilder label: () -> Label) {
                        self.label = label()
                    }
                }

                extension Badge where Label == Text {
                    init(label: LocalizedStringKey?) {
                        self.label = label.map {
                            Text($0)
                        }
                    }

                    @_disfavoredOverload
                    init(label: String?) {
                        self.label = label.map {
                            Text($0)
                        }
                    }
                }

                extension Badge where Label == Never {
                    init() {
                        self.label = nil
                    }
                }
                """,
            macros: testMacros
        )
    }

    // MARK: - Two slot tests

    func testTwoSlotsTextAndOptional() {
        let testMacros: [String: Macro.Type] = ["Slots": SlotMacro.self, "Slot": SlotPropertyMacro.self]
        assertMacroExpansion(
            """
            @Slots
            struct Card<Title: View, Actions: View>: View {
                @Slot(.text) var title: Title
                var actions: Actions?
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
                struct Card<Title: View, Actions: View>: View {
                    var title: Title
                    var actions: Actions?
                    var body: some View { EmptyView() }

                    init(@ViewBuilder title: () -> Title, @ViewBuilder actions: () -> Actions) {
                        self.title = title()
                        self.actions = actions()
                    }
                }

                extension Card where Actions == Never {
                    init(@ViewBuilder title: () -> Title) {
                        self.title = title()
                        self.actions = nil
                    }
                }

                extension Card where Title == Text {
                    init(title: LocalizedStringKey, @ViewBuilder actions: () -> Actions) {
                        self.title = Text(title)
                        self.actions = actions()
                    }

                    @_disfavoredOverload
                    init(title: String, @ViewBuilder actions: () -> Actions) {
                        self.title = Text(title)
                        self.actions = actions()
                    }
                }

                extension Card where Title == Text, Actions == Never {
                    init(title: LocalizedStringKey) {
                        self.title = Text(title)
                        self.actions = nil
                    }

                    @_disfavoredOverload
                    init(title: String) {
                        self.title = Text(title)
                        self.actions = nil
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testTwoSlotsText() {
        let testMacros: [String: Macro.Type] = ["Slots": SlotMacro.self, "Slot": SlotPropertyMacro.self]
        assertMacroExpansion(
            """
            @Slots
            struct Card<Title: View, Footer: View>: View {
                @Slot(.text) var title: Title
                var footer: Footer?
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
                struct Card<Title: View, Footer: View>: View {
                    var title: Title
                    var footer: Footer?
                    var body: some View { EmptyView() }

                    init(@ViewBuilder title: () -> Title, @ViewBuilder footer: () -> Footer) {
                        self.title = title()
                        self.footer = footer()
                    }
                }

                extension Card where Footer == Never {
                    init(@ViewBuilder title: () -> Title) {
                        self.title = title()
                        self.footer = nil
                    }
                }

                extension Card where Title == Text {
                    init(title: LocalizedStringKey, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.footer = footer()
                    }

                    @_disfavoredOverload
                    init(title: String, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.footer = footer()
                    }
                }

                extension Card where Title == Text, Footer == Never {
                    init(title: LocalizedStringKey) {
                        self.title = Text(title)
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(title: String) {
                        self.title = Text(title)
                        self.footer = nil
                    }
                }
                """,
            macros: testMacros
        )
    }

    // MARK: - Three slot test

    func testThreeSlots() {
        let testMacros: [String: Macro.Type] = ["Slots": SlotMacro.self, "Slot": SlotPropertyMacro.self]
        assertMacroExpansion(
            """
            @Slots
            struct Card<Title: View, Subtitle: View, Actions: View>: View {
                @Slot(.text) var title: Title
                @Slot(.text) var subtitle: Subtitle
                var actions: Actions?
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
                struct Card<Title: View, Subtitle: View, Actions: View>: View {
                    var title: Title
                    var subtitle: Subtitle
                    var actions: Actions?
                    var body: some View { EmptyView() }

                    init(@ViewBuilder title: () -> Title, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder actions: () -> Actions) {
                        self.title = title()
                        self.subtitle = subtitle()
                        self.actions = actions()
                    }
                }

                extension Card where Actions == Never {
                    init(@ViewBuilder title: () -> Title, @ViewBuilder subtitle: () -> Subtitle) {
                        self.title = title()
                        self.subtitle = subtitle()
                        self.actions = nil
                    }
                }

                extension Card where Subtitle == Text {
                    init(subtitle: LocalizedStringKey, @ViewBuilder title: () -> Title, @ViewBuilder actions: () -> Actions) {
                        self.subtitle = Text(subtitle)
                        self.title = title()
                        self.actions = actions()
                    }

                    @_disfavoredOverload
                    init(subtitle: String, @ViewBuilder title: () -> Title, @ViewBuilder actions: () -> Actions) {
                        self.subtitle = Text(subtitle)
                        self.title = title()
                        self.actions = actions()
                    }
                }

                extension Card where Subtitle == Text, Actions == Never {
                    init(subtitle: LocalizedStringKey, @ViewBuilder title: () -> Title) {
                        self.subtitle = Text(subtitle)
                        self.title = title()
                        self.actions = nil
                    }

                    @_disfavoredOverload
                    init(subtitle: String, @ViewBuilder title: () -> Title) {
                        self.subtitle = Text(subtitle)
                        self.title = title()
                        self.actions = nil
                    }
                }

                extension Card where Title == Text {
                    init(title: LocalizedStringKey, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder actions: () -> Actions) {
                        self.title = Text(title)
                        self.subtitle = subtitle()
                        self.actions = actions()
                    }

                    @_disfavoredOverload
                    init(title: String, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder actions: () -> Actions) {
                        self.title = Text(title)
                        self.subtitle = subtitle()
                        self.actions = actions()
                    }
                }

                extension Card where Title == Text, Actions == Never {
                    init(title: LocalizedStringKey, @ViewBuilder subtitle: () -> Subtitle) {
                        self.title = Text(title)
                        self.subtitle = subtitle()
                        self.actions = nil
                    }

                    @_disfavoredOverload
                    init(title: String, @ViewBuilder subtitle: () -> Subtitle) {
                        self.title = Text(title)
                        self.subtitle = subtitle()
                        self.actions = nil
                    }
                }

                extension Card where Title == Text, Subtitle == Text {
                    init(title: LocalizedStringKey, subtitle: LocalizedStringKey, @ViewBuilder actions: () -> Actions) {
                        self.title = Text(title)
                        self.subtitle = Text(subtitle)
                        self.actions = actions()
                    }

                    @_disfavoredOverload
                    init(title: LocalizedStringKey, subtitle: String, @ViewBuilder actions: () -> Actions) {
                        self.title = Text(title)
                        self.subtitle = Text(subtitle)
                        self.actions = actions()
                    }

                    @_disfavoredOverload
                    init(title: String, subtitle: LocalizedStringKey, @ViewBuilder actions: () -> Actions) {
                        self.title = Text(title)
                        self.subtitle = Text(subtitle)
                        self.actions = actions()
                    }

                    @_disfavoredOverload
                    init(title: String, subtitle: String, @ViewBuilder actions: () -> Actions) {
                        self.title = Text(title)
                        self.subtitle = Text(subtitle)
                        self.actions = actions()
                    }
                }

                extension Card where Title == Text, Subtitle == Text, Actions == Never {
                    init(title: LocalizedStringKey, subtitle: LocalizedStringKey) {
                        self.title = Text(title)
                        self.subtitle = Text(subtitle)
                        self.actions = nil
                    }

                    @_disfavoredOverload
                    init(title: LocalizedStringKey, subtitle: String) {
                        self.title = Text(title)
                        self.subtitle = Text(subtitle)
                        self.actions = nil
                    }

                    @_disfavoredOverload
                    init(title: String, subtitle: LocalizedStringKey) {
                        self.title = Text(title)
                        self.subtitle = Text(subtitle)
                        self.actions = nil
                    }

                    @_disfavoredOverload
                    init(title: String, subtitle: String) {
                        self.title = Text(title)
                        self.subtitle = Text(subtitle)
                        self.actions = nil
                    }
                }
                """,
            macros: testMacros
        )
    }

    // MARK: - Four slot test

    func testFourSlots() {
        let testMacros: [String: Macro.Type] = ["Slots": SlotMacro.self, "Slot": SlotPropertyMacro.self]
        assertMacroExpansion(
            """
            @Slots
            struct Card<Title: View, Subtitle: View, Body: View, Footer: View>: View {
                @Slot(.text) var title: Title
                var subtitle: Subtitle?
                @Slot(.text) var body_: Body
                var footer: Footer?
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
                struct Card<Title: View, Subtitle: View, Body: View, Footer: View>: View {
                    var title: Title
                    var subtitle: Subtitle?
                    var body_: Body
                    var footer: Footer?
                    var body: some View { EmptyView() }

                    init(@ViewBuilder title: () -> Title, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder body_: () -> Body, @ViewBuilder footer: () -> Footer) {
                        self.title = title()
                        self.subtitle = subtitle()
                        self.body_ = body_()
                        self.footer = footer()
                    }
                }

                extension Card where Footer == Never {
                    init(@ViewBuilder title: () -> Title, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder body_: () -> Body) {
                        self.title = title()
                        self.subtitle = subtitle()
                        self.body_ = body_()
                        self.footer = nil
                    }
                }

                extension Card where Body == Text {
                    init(body_: LocalizedStringKey, @ViewBuilder title: () -> Title, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder footer: () -> Footer) {
                        self.body_ = Text(body_)
                        self.title = title()
                        self.subtitle = subtitle()
                        self.footer = footer()
                    }

                    @_disfavoredOverload
                    init(body_: String, @ViewBuilder title: () -> Title, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder footer: () -> Footer) {
                        self.body_ = Text(body_)
                        self.title = title()
                        self.subtitle = subtitle()
                        self.footer = footer()
                    }
                }

                extension Card where Body == Text, Footer == Never {
                    init(body_: LocalizedStringKey, @ViewBuilder title: () -> Title, @ViewBuilder subtitle: () -> Subtitle) {
                        self.body_ = Text(body_)
                        self.title = title()
                        self.subtitle = subtitle()
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(body_: String, @ViewBuilder title: () -> Title, @ViewBuilder subtitle: () -> Subtitle) {
                        self.body_ = Text(body_)
                        self.title = title()
                        self.subtitle = subtitle()
                        self.footer = nil
                    }
                }

                extension Card where Subtitle == Never {
                    init(@ViewBuilder title: () -> Title, @ViewBuilder body_: () -> Body, @ViewBuilder footer: () -> Footer) {
                        self.title = title()
                        self.body_ = body_()
                        self.footer = footer()
                        self.subtitle = nil
                    }
                }

                extension Card where Subtitle == Never, Footer == Never {
                    init(@ViewBuilder title: () -> Title, @ViewBuilder body_: () -> Body) {
                        self.title = title()
                        self.body_ = body_()
                        self.subtitle = nil
                        self.footer = nil
                    }
                }

                extension Card where Subtitle == Never, Body == Text {
                    init(body_: LocalizedStringKey, @ViewBuilder title: () -> Title, @ViewBuilder footer: () -> Footer) {
                        self.body_ = Text(body_)
                        self.title = title()
                        self.footer = footer()
                        self.subtitle = nil
                    }

                    @_disfavoredOverload
                    init(body_: String, @ViewBuilder title: () -> Title, @ViewBuilder footer: () -> Footer) {
                        self.body_ = Text(body_)
                        self.title = title()
                        self.footer = footer()
                        self.subtitle = nil
                    }
                }

                extension Card where Subtitle == Never, Body == Text, Footer == Never {
                    init(body_: LocalizedStringKey, @ViewBuilder title: () -> Title) {
                        self.body_ = Text(body_)
                        self.title = title()
                        self.subtitle = nil
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(body_: String, @ViewBuilder title: () -> Title) {
                        self.body_ = Text(body_)
                        self.title = title()
                        self.subtitle = nil
                        self.footer = nil
                    }
                }

                extension Card where Title == Text {
                    init(title: LocalizedStringKey, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder body_: () -> Body, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.subtitle = subtitle()
                        self.body_ = body_()
                        self.footer = footer()
                    }

                    @_disfavoredOverload
                    init(title: String, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder body_: () -> Body, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.subtitle = subtitle()
                        self.body_ = body_()
                        self.footer = footer()
                    }
                }

                extension Card where Title == Text, Footer == Never {
                    init(title: LocalizedStringKey, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder body_: () -> Body) {
                        self.title = Text(title)
                        self.subtitle = subtitle()
                        self.body_ = body_()
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(title: String, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder body_: () -> Body) {
                        self.title = Text(title)
                        self.subtitle = subtitle()
                        self.body_ = body_()
                        self.footer = nil
                    }
                }

                extension Card where Title == Text, Body == Text {
                    init(title: LocalizedStringKey, body_: LocalizedStringKey, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.subtitle = subtitle()
                        self.footer = footer()
                    }

                    @_disfavoredOverload
                    init(title: LocalizedStringKey, body_: String, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.subtitle = subtitle()
                        self.footer = footer()
                    }

                    @_disfavoredOverload
                    init(title: String, body_: LocalizedStringKey, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.subtitle = subtitle()
                        self.footer = footer()
                    }

                    @_disfavoredOverload
                    init(title: String, body_: String, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.subtitle = subtitle()
                        self.footer = footer()
                    }
                }

                extension Card where Title == Text, Body == Text, Footer == Never {
                    init(title: LocalizedStringKey, body_: LocalizedStringKey, @ViewBuilder subtitle: () -> Subtitle) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.subtitle = subtitle()
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(title: LocalizedStringKey, body_: String, @ViewBuilder subtitle: () -> Subtitle) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.subtitle = subtitle()
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(title: String, body_: LocalizedStringKey, @ViewBuilder subtitle: () -> Subtitle) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.subtitle = subtitle()
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(title: String, body_: String, @ViewBuilder subtitle: () -> Subtitle) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.subtitle = subtitle()
                        self.footer = nil
                    }
                }

                extension Card where Title == Text, Subtitle == Never {
                    init(title: LocalizedStringKey, @ViewBuilder body_: () -> Body, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.body_ = body_()
                        self.footer = footer()
                        self.subtitle = nil
                    }

                    @_disfavoredOverload
                    init(title: String, @ViewBuilder body_: () -> Body, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.body_ = body_()
                        self.footer = footer()
                        self.subtitle = nil
                    }
                }

                extension Card where Title == Text, Subtitle == Never, Footer == Never {
                    init(title: LocalizedStringKey, @ViewBuilder body_: () -> Body) {
                        self.title = Text(title)
                        self.body_ = body_()
                        self.subtitle = nil
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(title: String, @ViewBuilder body_: () -> Body) {
                        self.title = Text(title)
                        self.body_ = body_()
                        self.subtitle = nil
                        self.footer = nil
                    }
                }

                extension Card where Title == Text, Subtitle == Never, Body == Text {
                    init(title: LocalizedStringKey, body_: LocalizedStringKey, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.footer = footer()
                        self.subtitle = nil
                    }

                    @_disfavoredOverload
                    init(title: LocalizedStringKey, body_: String, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.footer = footer()
                        self.subtitle = nil
                    }

                    @_disfavoredOverload
                    init(title: String, body_: LocalizedStringKey, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.footer = footer()
                        self.subtitle = nil
                    }

                    @_disfavoredOverload
                    init(title: String, body_: String, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.footer = footer()
                        self.subtitle = nil
                    }
                }

                extension Card where Title == Text, Subtitle == Never, Body == Text, Footer == Never {
                    init(title: LocalizedStringKey, body_: LocalizedStringKey) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.subtitle = nil
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(title: LocalizedStringKey, body_: String) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.subtitle = nil
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(title: String, body_: LocalizedStringKey) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.subtitle = nil
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(title: String, body_: String) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.subtitle = nil
                        self.footer = nil
                    }
                }
                """,
            macros: testMacros
        )
    }

    // Plain stored properties WITH a default value appear in every generated init
    // with the default value, so callers can omit or override them.
    func testPlainPropertyWithDefault() {
        let testMacros: [String: Macro.Type] = ["Slots": SlotMacro.self, "Slot": SlotPropertyMacro.self]
        assertMacroExpansion(
            """
            @Slots
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

                    init(count: Int = 0, @ViewBuilder label: () -> Label) {
                        self.count = count
                        self.label = label()
                    }
                }

                extension Badge where Label == Text {
                    init(count: Int = 0, label: LocalizedStringKey) {
                        self.count = count
                        self.label = Text(label)
                    }

                    @_disfavoredOverload
                    init(count: Int = 0, label: String) {
                        self.count = count
                        self.label = Text(label)
                    }
                }
                """,
            macros: testMacros
        )
    }

    // MARK: - Diagnostic tests

    // Plain stored properties — required ones appear as required params, defaulted ones
    // appear with their default value so callers can omit or override them.
    func testPlainPropertyWithoutDefault() {
        let testMacros: [String: Macro.Type] = ["Slots": SlotMacro.self, "Slot": SlotPropertyMacro.self]
        assertMacroExpansion(
            """
            @Slots
            struct Banner<Icon: View, Label: View>: View {
                var isEnabled: Bool
                var badge: Int = 0
                var icon: Icon?
                @Slot(.text) var label: Label
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
                struct Banner<Icon: View, Label: View>: View {
                    var isEnabled: Bool
                    var badge: Int = 0
                    var icon: Icon?
                    var label: Label
                    var body: some View { EmptyView() }

                    init(isEnabled: Bool, badge: Int = 0, @ViewBuilder icon: () -> Icon, @ViewBuilder label: () -> Label) {
                        self.isEnabled = isEnabled
                        self.badge = badge
                        self.icon = icon()
                        self.label = label()
                    }
                }

                extension Banner where Label == Text {
                    init(isEnabled: Bool, badge: Int = 0, label: LocalizedStringKey, @ViewBuilder icon: () -> Icon) {
                        self.isEnabled = isEnabled
                        self.badge = badge
                        self.label = Text(label)
                        self.icon = icon()
                    }

                    @_disfavoredOverload
                    init(isEnabled: Bool, badge: Int = 0, label: String, @ViewBuilder icon: () -> Icon) {
                        self.isEnabled = isEnabled
                        self.badge = badge
                        self.label = Text(label)
                        self.icon = icon()
                    }
                }

                extension Banner where Icon == Never {
                    init(isEnabled: Bool, badge: Int = 0, @ViewBuilder label: () -> Label) {
                        self.isEnabled = isEnabled
                        self.badge = badge
                        self.label = label()
                        self.icon = nil
                    }
                }

                extension Banner where Icon == Never, Label == Text {
                    init(isEnabled: Bool, badge: Int = 0, label: LocalizedStringKey) {
                        self.isEnabled = isEnabled
                        self.badge = badge
                        self.label = Text(label)
                        self.icon = nil
                    }

                    @_disfavoredOverload
                    init(isEnabled: Bool, badge: Int = 0, label: String) {
                        self.isEnabled = isEnabled
                        self.badge = badge
                        self.label = Text(label)
                        self.icon = nil
                    }
                }
                """,
            macros: testMacros
        )
    }

    // MARK: - Image slot tests

    func testSingleSlotImage() {
        let testMacros: [String: Macro.Type] = ["Slots": SlotMacro.self, "Slot": SlotPropertyMacro.self]
        assertMacroExpansion(
            """
            @Slots
            struct Tag<Icon: View>: View {
                @Slot(.image) var icon: Icon
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
                struct Tag<Icon: View>: View {
                    var icon: Icon
                    var body: some View { EmptyView() }

                    init(@ViewBuilder icon: () -> Icon) {
                        self.icon = icon()
                    }
                }

                extension Tag where Icon == Image {
                    init(iconSystemName: String) {
                        self.icon = Image(systemName: iconSystemName)
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testImageAndTextSlots() {
        let testMacros: [String: Macro.Type] = ["Slots": SlotMacro.self, "Slot": SlotPropertyMacro.self]
        assertMacroExpansion(
            """
            @Slots
            struct Chip<Icon: View, Label: View>: View {
                @Slot(.image) var icon: Icon?
                @Slot(.text) var label: Label
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
                struct Chip<Icon: View, Label: View>: View {
                    var icon: Icon?
                    var label: Label
                    var body: some View { EmptyView() }

                    init(@ViewBuilder icon: () -> Icon, @ViewBuilder label: () -> Label) {
                        self.icon = icon()
                        self.label = label()
                    }
                }

                extension Chip where Label == Text {
                    init(label: LocalizedStringKey, @ViewBuilder icon: () -> Icon) {
                        self.label = Text(label)
                        self.icon = icon()
                    }

                    @_disfavoredOverload
                    init(label: String, @ViewBuilder icon: () -> Icon) {
                        self.label = Text(label)
                        self.icon = icon()
                    }
                }

                extension Chip where Icon == Image {
                    init(iconSystemName: String?, @ViewBuilder label: () -> Label) {
                        self.icon = iconSystemName.map {
                            Image(systemName: $0)
                        }
                        self.label = label()
                    }
                }

                extension Chip where Icon == Image, Label == Text {
                    init(iconSystemName: String?, label: LocalizedStringKey) {
                        self.icon = iconSystemName.map {
                            Image(systemName: $0)
                        }
                        self.label = Text(label)
                    }

                    @_disfavoredOverload
                    init(iconSystemName: String?, label: String) {
                        self.icon = iconSystemName.map {
                            Image(systemName: $0)
                        }
                        self.label = Text(label)
                    }
                }

                extension Chip where Icon == Never {
                    init(@ViewBuilder label: () -> Label) {
                        self.label = label()
                        self.icon = nil
                    }
                }

                extension Chip where Icon == Never, Label == Text {
                    init(label: LocalizedStringKey) {
                        self.label = Text(label)
                        self.icon = nil
                    }

                    @_disfavoredOverload
                    init(label: String) {
                        self.label = Text(label)
                        self.icon = nil
                    }
                }
                """,
            macros: testMacros
        )
    }

    // MARK: - Parameter ordering tests

    func testClosurePropertyOrdering() {
        let testMacros: [String: Macro.Type] = ["Slots": SlotMacro.self, "Slot": SlotPropertyMacro.self]
        assertMacroExpansion(
            """
            @Slots
            struct ActionButton<Label: View>: View {
                var action: () -> Void
                @Slot(.text) var label: Label
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
                struct ActionButton<Label: View>: View {
                    var action: () -> Void
                    var label: Label
                    var body: some View { EmptyView() }

                    init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
                        self.action = action
                        self.label = label()
                    }
                }

                extension ActionButton where Label == Text {
                    init(label: LocalizedStringKey, action: @escaping () -> Void) {
                        self.label = Text(label)
                        self.action = action
                    }

                    @_disfavoredOverload
                    init(label: String, action: @escaping () -> Void) {
                        self.label = Text(label)
                        self.action = action
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testParameterTierOrdering() {
        let testMacros: [String: Macro.Type] = ["Slots": SlotMacro.self, "Slot": SlotPropertyMacro.self]
        // Verifies: value params → closure params → @ViewBuilder params
        assertMacroExpansion(
            """
            @Slots
            struct Composed<Label: View, Trailing: View>: View {
                var style: Int
                var onTap: () -> Void
                @Slot(.text) var label: Label
                var trailing: Trailing?
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
                struct Composed<Label: View, Trailing: View>: View {
                    var style: Int
                    var onTap: () -> Void
                    var label: Label
                    var trailing: Trailing?
                    var body: some View { EmptyView() }

                    init(style: Int, onTap: @escaping () -> Void, @ViewBuilder label: () -> Label, @ViewBuilder trailing: () -> Trailing) {
                        self.style = style
                        self.onTap = onTap
                        self.label = label()
                        self.trailing = trailing()
                    }
                }

                extension Composed where Trailing == Never {
                    init(style: Int, onTap: @escaping () -> Void, @ViewBuilder label: () -> Label) {
                        self.style = style
                        self.onTap = onTap
                        self.label = label()
                        self.trailing = nil
                    }
                }

                extension Composed where Label == Text {
                    init(style: Int, label: LocalizedStringKey, onTap: @escaping () -> Void, @ViewBuilder trailing: () -> Trailing) {
                        self.style = style
                        self.label = Text(label)
                        self.onTap = onTap
                        self.trailing = trailing()
                    }

                    @_disfavoredOverload
                    init(style: Int, label: String, onTap: @escaping () -> Void, @ViewBuilder trailing: () -> Trailing) {
                        self.style = style
                        self.label = Text(label)
                        self.onTap = onTap
                        self.trailing = trailing()
                    }
                }

                extension Composed where Label == Text, Trailing == Never {
                    init(style: Int, label: LocalizedStringKey, onTap: @escaping () -> Void) {
                        self.style = style
                        self.label = Text(label)
                        self.onTap = onTap
                        self.trailing = nil
                    }

                    @_disfavoredOverload
                    init(style: Int, label: String, onTap: @escaping () -> Void) {
                        self.style = style
                        self.label = Text(label)
                        self.onTap = onTap
                        self.trailing = nil
                    }
                }
                """,
            macros: testMacros
        )
    }

    // MARK: - Init limit test

    func testTooManyInitsEmitsError() {
        let testMacros: [String: Macro.Type] = ["Slots": SlotMacro.self, "Slot": SlotPropertyMacro.self]
        // 7 slots all with .text + .image + optional = 5 modes each = 5^7 = 78,125 inits
        assertMacroExpansion(
            """
            @Slots
            struct Overload<A: View, B: View, C: View, D: View, E: View, F: View, G: View>: View {
                @Slot(.text, .image) var a: A?
                @Slot(.text, .image) var b: B?
                @Slot(.text, .image) var c: C?
                @Slot(.text, .image) var d: D?
                @Slot(.text, .image) var e: E?
                @Slot(.text, .image) var f: F?
                @Slot(.text, .image) var g: G?
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
                struct Overload<A: View, B: View, C: View, D: View, E: View, F: View, G: View>: View {
                    var a: A?
                    var b: B?
                    var c: C?
                    var d: D?
                    var e: E?
                    var f: F?
                    var g: G?
                    var body: some View { EmptyView() }

                    init(@ViewBuilder a: () -> A, @ViewBuilder b: () -> B, @ViewBuilder c: () -> C, @ViewBuilder d: () -> D, @ViewBuilder e: () -> E, @ViewBuilder f: () -> F, @ViewBuilder g: () -> G) {
                        self.a = a()
                        self.b = b()
                        self.c = c()
                        self.d = d()
                        self.e = e()
                        self.f = f()
                        self.g = g()
                    }
                }
                """,
            diagnostics: [
                DiagnosticSpec(
                    message:
                        "@Slots would generate 78125 initializers (limit is 512); reduce the number of slots or slot options to stay within the limit",
                    line: 1, column: 1)
            ],
            macros: testMacros
        )
    }

}
