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
                    init(@ViewBuilder title: () -> Title, subtitle: LocalizedStringKey, @ViewBuilder actions: () -> Actions) {
                        self.title = title()
                        self.subtitle = Text(subtitle)
                        self.actions = actions()
                    }

                    @_disfavoredOverload
                    init(@ViewBuilder title: () -> Title, subtitle: String, @ViewBuilder actions: () -> Actions) {
                        self.title = title()
                        self.subtitle = Text(subtitle)
                        self.actions = actions()
                    }
                }

                extension Card where Subtitle == Text, Actions == Never {
                    init(@ViewBuilder title: () -> Title, subtitle: LocalizedStringKey) {
                        self.title = title()
                        self.subtitle = Text(subtitle)
                        self.actions = nil
                    }

                    @_disfavoredOverload
                    init(@ViewBuilder title: () -> Title, subtitle: String) {
                        self.title = title()
                        self.subtitle = Text(subtitle)
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
                    init(@ViewBuilder title: () -> Title, @ViewBuilder subtitle: () -> Subtitle, body_: LocalizedStringKey, @ViewBuilder footer: () -> Footer) {
                        self.title = title()
                        self.subtitle = subtitle()
                        self.body_ = Text(body_)
                        self.footer = footer()
                    }

                    @_disfavoredOverload
                    init(@ViewBuilder title: () -> Title, @ViewBuilder subtitle: () -> Subtitle, body_: String, @ViewBuilder footer: () -> Footer) {
                        self.title = title()
                        self.subtitle = subtitle()
                        self.body_ = Text(body_)
                        self.footer = footer()
                    }
                }

                extension Card where Body == Text, Footer == Never {
                    init(@ViewBuilder title: () -> Title, @ViewBuilder subtitle: () -> Subtitle, body_: LocalizedStringKey) {
                        self.title = title()
                        self.subtitle = subtitle()
                        self.body_ = Text(body_)
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(@ViewBuilder title: () -> Title, @ViewBuilder subtitle: () -> Subtitle, body_: String) {
                        self.title = title()
                        self.subtitle = subtitle()
                        self.body_ = Text(body_)
                        self.footer = nil
                    }
                }

                extension Card where Subtitle == Never {
                    init(@ViewBuilder title: () -> Title, @ViewBuilder body_: () -> Body, @ViewBuilder footer: () -> Footer) {
                        self.title = title()
                        self.subtitle = nil
                        self.body_ = body_()
                        self.footer = footer()
                    }
                }

                extension Card where Subtitle == Never, Footer == Never {
                    init(@ViewBuilder title: () -> Title, @ViewBuilder body_: () -> Body) {
                        self.title = title()
                        self.subtitle = nil
                        self.body_ = body_()
                        self.footer = nil
                    }
                }

                extension Card where Subtitle == Never, Body == Text {
                    init(@ViewBuilder title: () -> Title, body_: LocalizedStringKey, @ViewBuilder footer: () -> Footer) {
                        self.title = title()
                        self.subtitle = nil
                        self.body_ = Text(body_)
                        self.footer = footer()
                    }

                    @_disfavoredOverload
                    init(@ViewBuilder title: () -> Title, body_: String, @ViewBuilder footer: () -> Footer) {
                        self.title = title()
                        self.subtitle = nil
                        self.body_ = Text(body_)
                        self.footer = footer()
                    }
                }

                extension Card where Subtitle == Never, Body == Text, Footer == Never {
                    init(@ViewBuilder title: () -> Title, body_: LocalizedStringKey) {
                        self.title = title()
                        self.subtitle = nil
                        self.body_ = Text(body_)
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(@ViewBuilder title: () -> Title, body_: String) {
                        self.title = title()
                        self.subtitle = nil
                        self.body_ = Text(body_)
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
                    init(title: LocalizedStringKey, @ViewBuilder subtitle: () -> Subtitle, body_: LocalizedStringKey, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.subtitle = subtitle()
                        self.body_ = Text(body_)
                        self.footer = footer()
                    }

                    @_disfavoredOverload
                    init(title: LocalizedStringKey, @ViewBuilder subtitle: () -> Subtitle, body_: String, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.subtitle = subtitle()
                        self.body_ = Text(body_)
                        self.footer = footer()
                    }

                    @_disfavoredOverload
                    init(title: String, @ViewBuilder subtitle: () -> Subtitle, body_: LocalizedStringKey, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.subtitle = subtitle()
                        self.body_ = Text(body_)
                        self.footer = footer()
                    }

                    @_disfavoredOverload
                    init(title: String, @ViewBuilder subtitle: () -> Subtitle, body_: String, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.subtitle = subtitle()
                        self.body_ = Text(body_)
                        self.footer = footer()
                    }
                }

                extension Card where Title == Text, Body == Text, Footer == Never {
                    init(title: LocalizedStringKey, @ViewBuilder subtitle: () -> Subtitle, body_: LocalizedStringKey) {
                        self.title = Text(title)
                        self.subtitle = subtitle()
                        self.body_ = Text(body_)
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(title: LocalizedStringKey, @ViewBuilder subtitle: () -> Subtitle, body_: String) {
                        self.title = Text(title)
                        self.subtitle = subtitle()
                        self.body_ = Text(body_)
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(title: String, @ViewBuilder subtitle: () -> Subtitle, body_: LocalizedStringKey) {
                        self.title = Text(title)
                        self.subtitle = subtitle()
                        self.body_ = Text(body_)
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(title: String, @ViewBuilder subtitle: () -> Subtitle, body_: String) {
                        self.title = Text(title)
                        self.subtitle = subtitle()
                        self.body_ = Text(body_)
                        self.footer = nil
                    }
                }

                extension Card where Title == Text, Subtitle == Never {
                    init(title: LocalizedStringKey, @ViewBuilder body_: () -> Body, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.subtitle = nil
                        self.body_ = body_()
                        self.footer = footer()
                    }

                    @_disfavoredOverload
                    init(title: String, @ViewBuilder body_: () -> Body, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.subtitle = nil
                        self.body_ = body_()
                        self.footer = footer()
                    }
                }

                extension Card where Title == Text, Subtitle == Never, Footer == Never {
                    init(title: LocalizedStringKey, @ViewBuilder body_: () -> Body) {
                        self.title = Text(title)
                        self.subtitle = nil
                        self.body_ = body_()
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(title: String, @ViewBuilder body_: () -> Body) {
                        self.title = Text(title)
                        self.subtitle = nil
                        self.body_ = body_()
                        self.footer = nil
                    }
                }

                extension Card where Title == Text, Subtitle == Never, Body == Text {
                    init(title: LocalizedStringKey, body_: LocalizedStringKey, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.subtitle = nil
                        self.body_ = Text(body_)
                        self.footer = footer()
                    }

                    @_disfavoredOverload
                    init(title: LocalizedStringKey, body_: String, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.subtitle = nil
                        self.body_ = Text(body_)
                        self.footer = footer()
                    }

                    @_disfavoredOverload
                    init(title: String, body_: LocalizedStringKey, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.subtitle = nil
                        self.body_ = Text(body_)
                        self.footer = footer()
                    }

                    @_disfavoredOverload
                    init(title: String, body_: String, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.subtitle = nil
                        self.body_ = Text(body_)
                        self.footer = footer()
                    }
                }

                extension Card where Title == Text, Subtitle == Never, Body == Text, Footer == Never {
                    init(title: LocalizedStringKey, body_: LocalizedStringKey) {
                        self.title = Text(title)
                        self.subtitle = nil
                        self.body_ = Text(body_)
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(title: LocalizedStringKey, body_: String) {
                        self.title = Text(title)
                        self.subtitle = nil
                        self.body_ = Text(body_)
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(title: String, body_: LocalizedStringKey) {
                        self.title = Text(title)
                        self.subtitle = nil
                        self.body_ = Text(body_)
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(title: String, body_: String) {
                        self.title = Text(title)
                        self.subtitle = nil
                        self.body_ = Text(body_)
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
                    init(isEnabled: Bool, badge: Int = 0, @ViewBuilder icon: () -> Icon, label: LocalizedStringKey) {
                        self.isEnabled = isEnabled
                        self.badge = badge
                        self.icon = icon()
                        self.label = Text(label)
                    }

                    @_disfavoredOverload
                    init(isEnabled: Bool, badge: Int = 0, @ViewBuilder icon: () -> Icon, label: String) {
                        self.isEnabled = isEnabled
                        self.badge = badge
                        self.icon = icon()
                        self.label = Text(label)
                    }
                }

                extension Banner where Icon == Never {
                    init(isEnabled: Bool, badge: Int = 0, @ViewBuilder label: () -> Label) {
                        self.isEnabled = isEnabled
                        self.badge = badge
                        self.icon = nil
                        self.label = label()
                    }
                }

                extension Banner where Icon == Never, Label == Text {
                    init(isEnabled: Bool, badge: Int = 0, label: LocalizedStringKey) {
                        self.isEnabled = isEnabled
                        self.badge = badge
                        self.icon = nil
                        self.label = Text(label)
                    }

                    @_disfavoredOverload
                    init(isEnabled: Bool, badge: Int = 0, label: String) {
                        self.isEnabled = isEnabled
                        self.badge = badge
                        self.icon = nil
                        self.label = Text(label)
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
                    init(@ViewBuilder icon: () -> Icon, label: LocalizedStringKey) {
                        self.icon = icon()
                        self.label = Text(label)
                    }

                    @_disfavoredOverload
                    init(@ViewBuilder icon: () -> Icon, label: String) {
                        self.icon = icon()
                        self.label = Text(label)
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
                        self.icon = nil
                        self.label = label()
                    }
                }

                extension Chip where Icon == Never, Label == Text {
                    init(label: LocalizedStringKey) {
                        self.icon = nil
                        self.label = Text(label)
                    }

                    @_disfavoredOverload
                    init(label: String) {
                        self.icon = nil
                        self.label = Text(label)
                    }
                }
                """,
            macros: testMacros
        )
    }

}
