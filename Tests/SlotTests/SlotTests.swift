import SlotMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

nonisolated(unsafe) private let testMacros: [String: Macro.Type] = [
    "Slots": SlotMacro.self, "Slot": SlotPropertyMacro.self,
]

@MainActor
final class SlotTests: XCTestCase {

    // MARK: - Single slot tests

    func testSingleSlotText() {
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
                    init(label: LocalizedStringResource) {
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

    func testSingleSlotTextUnlabeled() {
        assertMacroExpansion(
            """
            @Slots
            struct Badge<Label: View>: View {
                @Slot(.text, .unlabeled) var label: Label
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
                    init(_ label: LocalizedStringResource) {
                        self.label = Text(label)
                    }

                    @_disfavoredOverload
                    init(_ label: String) {
                        self.label = Text(label)
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testSingleSlotOptional() {
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
                        self.icon = Optional(icon())
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
                        self.label = Optional(label())
                    }
                }

                extension Badge where Label == Text {
                    init(label: LocalizedStringResource?) {
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

    func testSingleSlotEmpty() {
        assertMacroExpansion(
            """
            @Slots
            struct Card<Actions: View>: View {
                @Slot(.empty) var actions: Actions
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
                struct Card<Actions: View>: View {
                    var actions: Actions
                    var body: some View { EmptyView() }

                    init(@ViewBuilder actions: () -> Actions) {
                        self.actions = actions()
                    }
                }

                extension Card where Actions == EmptyView {
                    init() {
                        self.actions = EmptyView()
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testSingleSlotTextAndEmpty() {
        assertMacroExpansion(
            """
            @Slots
            struct Card<Title: View>: View {
                @Slot(.text, .empty) var title: Title
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
                struct Card<Title: View>: View {
                    var title: Title
                    var body: some View { EmptyView() }

                    init(@ViewBuilder title: () -> Title) {
                        self.title = title()
                    }
                }

                extension Card where Title == Text {
                    init(title: LocalizedStringResource) {
                        self.title = Text(title)
                    }

                    @_disfavoredOverload
                    init(title: String) {
                        self.title = Text(title)
                    }
                }

                extension Card where Title == EmptyView {
                    init() {
                        self.title = EmptyView()
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testEmptyOnOptionalSlotErrors() {
        assertMacroExpansion(
            """
            @Slots
            struct Card<Actions: View>: View {
                @Slot(.empty) var actions: Actions?
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
                struct Card<Actions: View>: View {
                    var actions: Actions?
                    var body: some View { EmptyView() }

                    init(@ViewBuilder actions: () -> Actions) {
                        self.actions = Optional(actions())
                    }
                }

                extension Card where Actions == Never {
                    init() {
                        self.actions = nil
                    }
                }
                """,
            diagnostics: [
                DiagnosticSpec(
                    message:
                        "@Slot(.empty) on 'actions': .empty cannot be used on optional slots; optional slots already support omission",
                    line: 3, column: 5),
                DiagnosticSpec(
                    message:
                        "@Slot(.empty) on 'actions': .empty cannot be used on optional slots; optional slots already support omission",
                    line: 3, column: 5),
            ],
            macros: testMacros
        )
    }

    // MARK: - Two slot tests

    func testTwoSlotsTextAndOptional() {
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
                        self.actions = Optional(actions())
                    }
                }

                extension Card where Actions == Never {
                    init(@ViewBuilder title: () -> Title) {
                        self.title = title()
                        self.actions = nil
                    }
                }

                extension Card where Title == Text {
                    init(title: LocalizedStringResource, @ViewBuilder actions: () -> Actions) {
                        self.title = Text(title)
                        self.actions = Optional(actions())
                    }

                    @_disfavoredOverload
                    init(title: String, @ViewBuilder actions: () -> Actions) {
                        self.title = Text(title)
                        self.actions = Optional(actions())
                    }
                }

                extension Card where Title == Text, Actions == Never {
                    init(title: LocalizedStringResource) {
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
                        self.footer = Optional(footer())
                    }
                }

                extension Card where Footer == Never {
                    init(@ViewBuilder title: () -> Title) {
                        self.title = title()
                        self.footer = nil
                    }
                }

                extension Card where Title == Text {
                    init(title: LocalizedStringResource, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.footer = Optional(footer())
                    }

                    @_disfavoredOverload
                    init(title: String, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.footer = Optional(footer())
                    }
                }

                extension Card where Title == Text, Footer == Never {
                    init(title: LocalizedStringResource) {
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
                        self.actions = Optional(actions())
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
                    init(subtitle: LocalizedStringResource, @ViewBuilder title: () -> Title, @ViewBuilder actions: () -> Actions) {
                        self.subtitle = Text(subtitle)
                        self.title = title()
                        self.actions = Optional(actions())
                    }

                    @_disfavoredOverload
                    init(subtitle: String, @ViewBuilder title: () -> Title, @ViewBuilder actions: () -> Actions) {
                        self.subtitle = Text(subtitle)
                        self.title = title()
                        self.actions = Optional(actions())
                    }
                }

                extension Card where Subtitle == Text, Actions == Never {
                    init(subtitle: LocalizedStringResource, @ViewBuilder title: () -> Title) {
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
                    init(title: LocalizedStringResource, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder actions: () -> Actions) {
                        self.title = Text(title)
                        self.subtitle = subtitle()
                        self.actions = Optional(actions())
                    }

                    @_disfavoredOverload
                    init(title: String, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder actions: () -> Actions) {
                        self.title = Text(title)
                        self.subtitle = subtitle()
                        self.actions = Optional(actions())
                    }
                }

                extension Card where Title == Text, Actions == Never {
                    init(title: LocalizedStringResource, @ViewBuilder subtitle: () -> Subtitle) {
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
                    init(title: LocalizedStringResource, subtitle: LocalizedStringResource, @ViewBuilder actions: () -> Actions) {
                        self.title = Text(title)
                        self.subtitle = Text(subtitle)
                        self.actions = Optional(actions())
                    }

                    @_disfavoredOverload
                    init(title: LocalizedStringResource, subtitle: String, @ViewBuilder actions: () -> Actions) {
                        self.title = Text(title)
                        self.subtitle = Text(subtitle)
                        self.actions = Optional(actions())
                    }

                    @_disfavoredOverload
                    init(title: String, subtitle: LocalizedStringResource, @ViewBuilder actions: () -> Actions) {
                        self.title = Text(title)
                        self.subtitle = Text(subtitle)
                        self.actions = Optional(actions())
                    }

                    @_disfavoredOverload
                    init(title: String, subtitle: String, @ViewBuilder actions: () -> Actions) {
                        self.title = Text(title)
                        self.subtitle = Text(subtitle)
                        self.actions = Optional(actions())
                    }
                }

                extension Card where Title == Text, Subtitle == Text, Actions == Never {
                    init(title: LocalizedStringResource, subtitle: LocalizedStringResource) {
                        self.title = Text(title)
                        self.subtitle = Text(subtitle)
                        self.actions = nil
                    }

                    @_disfavoredOverload
                    init(title: LocalizedStringResource, subtitle: String) {
                        self.title = Text(title)
                        self.subtitle = Text(subtitle)
                        self.actions = nil
                    }

                    @_disfavoredOverload
                    init(title: String, subtitle: LocalizedStringResource) {
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
                        self.subtitle = Optional(subtitle())
                        self.body_ = body_()
                        self.footer = Optional(footer())
                    }
                }

                extension Card where Footer == Never {
                    init(@ViewBuilder title: () -> Title, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder body_: () -> Body) {
                        self.title = title()
                        self.subtitle = Optional(subtitle())
                        self.body_ = body_()
                        self.footer = nil
                    }
                }

                extension Card where Body == Text {
                    init(body_: LocalizedStringResource, @ViewBuilder title: () -> Title, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder footer: () -> Footer) {
                        self.body_ = Text(body_)
                        self.title = title()
                        self.subtitle = Optional(subtitle())
                        self.footer = Optional(footer())
                    }

                    @_disfavoredOverload
                    init(body_: String, @ViewBuilder title: () -> Title, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder footer: () -> Footer) {
                        self.body_ = Text(body_)
                        self.title = title()
                        self.subtitle = Optional(subtitle())
                        self.footer = Optional(footer())
                    }
                }

                extension Card where Body == Text, Footer == Never {
                    init(body_: LocalizedStringResource, @ViewBuilder title: () -> Title, @ViewBuilder subtitle: () -> Subtitle) {
                        self.body_ = Text(body_)
                        self.title = title()
                        self.subtitle = Optional(subtitle())
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(body_: String, @ViewBuilder title: () -> Title, @ViewBuilder subtitle: () -> Subtitle) {
                        self.body_ = Text(body_)
                        self.title = title()
                        self.subtitle = Optional(subtitle())
                        self.footer = nil
                    }
                }

                extension Card where Subtitle == Never {
                    init(@ViewBuilder title: () -> Title, @ViewBuilder body_: () -> Body, @ViewBuilder footer: () -> Footer) {
                        self.title = title()
                        self.body_ = body_()
                        self.footer = Optional(footer())
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
                    init(body_: LocalizedStringResource, @ViewBuilder title: () -> Title, @ViewBuilder footer: () -> Footer) {
                        self.body_ = Text(body_)
                        self.title = title()
                        self.footer = Optional(footer())
                        self.subtitle = nil
                    }

                    @_disfavoredOverload
                    init(body_: String, @ViewBuilder title: () -> Title, @ViewBuilder footer: () -> Footer) {
                        self.body_ = Text(body_)
                        self.title = title()
                        self.footer = Optional(footer())
                        self.subtitle = nil
                    }
                }

                extension Card where Subtitle == Never, Body == Text, Footer == Never {
                    init(body_: LocalizedStringResource, @ViewBuilder title: () -> Title) {
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
                    init(title: LocalizedStringResource, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder body_: () -> Body, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.subtitle = Optional(subtitle())
                        self.body_ = body_()
                        self.footer = Optional(footer())
                    }

                    @_disfavoredOverload
                    init(title: String, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder body_: () -> Body, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.subtitle = Optional(subtitle())
                        self.body_ = body_()
                        self.footer = Optional(footer())
                    }
                }

                extension Card where Title == Text, Footer == Never {
                    init(title: LocalizedStringResource, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder body_: () -> Body) {
                        self.title = Text(title)
                        self.subtitle = Optional(subtitle())
                        self.body_ = body_()
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(title: String, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder body_: () -> Body) {
                        self.title = Text(title)
                        self.subtitle = Optional(subtitle())
                        self.body_ = body_()
                        self.footer = nil
                    }
                }

                extension Card where Title == Text, Body == Text {
                    init(title: LocalizedStringResource, body_: LocalizedStringResource, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.subtitle = Optional(subtitle())
                        self.footer = Optional(footer())
                    }

                    @_disfavoredOverload
                    init(title: LocalizedStringResource, body_: String, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.subtitle = Optional(subtitle())
                        self.footer = Optional(footer())
                    }

                    @_disfavoredOverload
                    init(title: String, body_: LocalizedStringResource, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.subtitle = Optional(subtitle())
                        self.footer = Optional(footer())
                    }

                    @_disfavoredOverload
                    init(title: String, body_: String, @ViewBuilder subtitle: () -> Subtitle, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.subtitle = Optional(subtitle())
                        self.footer = Optional(footer())
                    }
                }

                extension Card where Title == Text, Body == Text, Footer == Never {
                    init(title: LocalizedStringResource, body_: LocalizedStringResource, @ViewBuilder subtitle: () -> Subtitle) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.subtitle = Optional(subtitle())
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(title: LocalizedStringResource, body_: String, @ViewBuilder subtitle: () -> Subtitle) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.subtitle = Optional(subtitle())
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(title: String, body_: LocalizedStringResource, @ViewBuilder subtitle: () -> Subtitle) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.subtitle = Optional(subtitle())
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(title: String, body_: String, @ViewBuilder subtitle: () -> Subtitle) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.subtitle = Optional(subtitle())
                        self.footer = nil
                    }
                }

                extension Card where Title == Text, Subtitle == Never {
                    init(title: LocalizedStringResource, @ViewBuilder body_: () -> Body, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.body_ = body_()
                        self.footer = Optional(footer())
                        self.subtitle = nil
                    }

                    @_disfavoredOverload
                    init(title: String, @ViewBuilder body_: () -> Body, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.body_ = body_()
                        self.footer = Optional(footer())
                        self.subtitle = nil
                    }
                }

                extension Card where Title == Text, Subtitle == Never, Footer == Never {
                    init(title: LocalizedStringResource, @ViewBuilder body_: () -> Body) {
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
                    init(title: LocalizedStringResource, body_: LocalizedStringResource, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.footer = Optional(footer())
                        self.subtitle = nil
                    }

                    @_disfavoredOverload
                    init(title: LocalizedStringResource, body_: String, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.footer = Optional(footer())
                        self.subtitle = nil
                    }

                    @_disfavoredOverload
                    init(title: String, body_: LocalizedStringResource, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.footer = Optional(footer())
                        self.subtitle = nil
                    }

                    @_disfavoredOverload
                    init(title: String, body_: String, @ViewBuilder footer: () -> Footer) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.footer = Optional(footer())
                        self.subtitle = nil
                    }
                }

                extension Card where Title == Text, Subtitle == Never, Body == Text, Footer == Never {
                    init(title: LocalizedStringResource, body_: LocalizedStringResource) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.subtitle = nil
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(title: LocalizedStringResource, body_: String) {
                        self.title = Text(title)
                        self.body_ = Text(body_)
                        self.subtitle = nil
                        self.footer = nil
                    }

                    @_disfavoredOverload
                    init(title: String, body_: LocalizedStringResource) {
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
                    init(count: Int = 0, label: LocalizedStringResource) {
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
                        self.icon = Optional(icon())
                        self.label = label()
                    }
                }

                extension Banner where Label == Text {
                    init(isEnabled: Bool, badge: Int = 0, label: LocalizedStringResource, @ViewBuilder icon: () -> Icon) {
                        self.isEnabled = isEnabled
                        self.badge = badge
                        self.label = Text(label)
                        self.icon = Optional(icon())
                    }

                    @_disfavoredOverload
                    init(isEnabled: Bool, badge: Int = 0, label: String, @ViewBuilder icon: () -> Icon) {
                        self.isEnabled = isEnabled
                        self.badge = badge
                        self.label = Text(label)
                        self.icon = Optional(icon())
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
                    init(isEnabled: Bool, badge: Int = 0, label: LocalizedStringResource) {
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

    func testOptionalPlainPropertyDefaultsToNil() {
        assertMacroExpansion(
            """
            @Slots
            struct Section<Title: View, Content: View>: View {
                var subtitle: String?
                @Slot(.text) var title: Title
                var content: Content
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
                struct Section<Title: View, Content: View>: View {
                    var subtitle: String?
                    var title: Title
                    var content: Content
                    var body: some View { EmptyView() }

                    init(subtitle: String? = nil, @ViewBuilder title: () -> Title, @ViewBuilder content: () -> Content) {
                        self.subtitle = subtitle
                        self.title = title()
                        self.content = content()
                    }
                }

                extension Section where Title == Text {
                    init(subtitle: String? = nil, title: LocalizedStringResource, @ViewBuilder content: () -> Content) {
                        self.subtitle = subtitle
                        self.title = Text(title)
                        self.content = content()
                    }

                    @_disfavoredOverload
                    init(subtitle: String? = nil, title: String, @ViewBuilder content: () -> Content) {
                        self.subtitle = subtitle
                        self.title = Text(title)
                        self.content = content()
                    }
                }
                """,
            macros: testMacros
        )
    }

    // MARK: - Image slot tests

    func testSingleSlotImage() {
        assertMacroExpansion(
            """
            @Slots
            struct Tag<Icon: View>: View {
                @Slot(.systemImage) var icon: Icon
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
        assertMacroExpansion(
            """
            @Slots
            struct Chip<Icon: View, Label: View>: View {
                @Slot(.systemImage) var icon: Icon?
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
                        self.icon = Optional(icon())
                        self.label = label()
                    }
                }

                extension Chip where Label == Text {
                    init(label: LocalizedStringResource, @ViewBuilder icon: () -> Icon) {
                        self.label = Text(label)
                        self.icon = Optional(icon())
                    }

                    @_disfavoredOverload
                    init(label: String, @ViewBuilder icon: () -> Icon) {
                        self.label = Text(label)
                        self.icon = Optional(icon())
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
                    init(iconSystemName: String?, label: LocalizedStringResource) {
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
                    init(label: LocalizedStringResource) {
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
                    init(label: LocalizedStringResource, action: @escaping () -> Void) {
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
                        self.trailing = Optional(trailing())
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
                    init(style: Int, label: LocalizedStringResource, onTap: @escaping () -> Void, @ViewBuilder trailing: () -> Trailing) {
                        self.style = style
                        self.label = Text(label)
                        self.onTap = onTap
                        self.trailing = Optional(trailing())
                    }

                    @_disfavoredOverload
                    init(style: Int, label: String, onTap: @escaping () -> Void, @ViewBuilder trailing: () -> Trailing) {
                        self.style = style
                        self.label = Text(label)
                        self.onTap = onTap
                        self.trailing = Optional(trailing())
                    }
                }

                extension Composed where Label == Text, Trailing == Never {
                    init(style: Int, label: LocalizedStringResource, onTap: @escaping () -> Void) {
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

    // MARK: - Property wrapper tests

    func testBindingProperty() {
        assertMacroExpansion(
            """
            @Slots
            struct Toggle<Label: View>: View {
                @Binding var isOn: Bool
                @Slot(.text) var label: Label
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
                struct Toggle<Label: View>: View {
                    @Binding var isOn: Bool
                    var label: Label
                    var body: some View { EmptyView() }

                    init(isOn: Binding<Bool>, @ViewBuilder label: () -> Label) {
                        self._isOn = isOn
                        self.label = label()
                    }
                }

                extension Toggle where Label == Text {
                    init(isOn: Binding<Bool>, label: LocalizedStringResource) {
                        self._isOn = isOn
                        self.label = Text(label)
                    }

                    @_disfavoredOverload
                    init(isOn: Binding<Bool>, label: String) {
                        self._isOn = isOn
                        self.label = Text(label)
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testStatePropertySkipped() {
        assertMacroExpansion(
            """
            @Slots
            struct Counter<Label: View>: View {
                @State var count: Int
                @Slot(.text) var label: Label
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
                struct Counter<Label: View>: View {
                    @State var count: Int
                    var label: Label
                    var body: some View { EmptyView() }

                    init(@ViewBuilder label: () -> Label) {
                        self.label = label()
                    }
                }

                extension Counter where Label == Text {
                    init(label: LocalizedStringResource) {
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

    // MARK: - Resolver tests

    func testResolverOnRequiredSlot() {
        assertMacroExpansion(
            """
            @Slots
            struct EventRow<Label: View>: View {
                @Slot(SomeResolver.self) var label: Label
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
                struct EventRow<Label: View>: View {
                    var label: Label
                    var body: some View { EmptyView() }

                    init(@ViewBuilder label: () -> Label) {
                        self.label = label()
                    }
                }

                extension EventRow where Label == SomeResolver.Output {
                    init(label: SomeResolver.Input) {
                        self.label = SomeResolver.resolve(label)
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testResolverOnOptionalSlot() {
        assertMacroExpansion(
            """
            @Slots
            struct EventRow<Icon: View>: View {
                @Slot(SomeResolver.self) var icon: Icon?
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
                struct EventRow<Icon: View>: View {
                    var icon: Icon?
                    var body: some View { EmptyView() }

                    init(@ViewBuilder icon: () -> Icon) {
                        self.icon = Optional(icon())
                    }
                }

                extension EventRow where Icon == SomeResolver.Output {
                    init(icon: SomeResolver.Input?) {
                        self.icon = icon.map {
                            SomeResolver.resolve($0)
                        }
                    }
                }

                extension EventRow where Icon == Never {
                    init() {
                        self.icon = nil
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testResolverWithTextOnOtherSlot() {
        assertMacroExpansion(
            """
            @Slots
            struct EventCard<Title: View, When: View>: View {
                @Slot(.text) var title: Title
                @Slot(DateResolver.self) var when_: When
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
                struct EventCard<Title: View, When: View>: View {
                    var title: Title
                    var when_: When
                    var body: some View { EmptyView() }

                    init(@ViewBuilder title: () -> Title, @ViewBuilder when_: () -> When) {
                        self.title = title()
                        self.when_ = when_()
                    }
                }

                extension EventCard where When == DateResolver.Output {
                    init(when_: DateResolver.Input, @ViewBuilder title: () -> Title) {
                        self.when_ = DateResolver.resolve(when_)
                        self.title = title()
                    }
                }

                extension EventCard where Title == Text {
                    init(title: LocalizedStringResource, @ViewBuilder when_: () -> When) {
                        self.title = Text(title)
                        self.when_ = when_()
                    }

                    @_disfavoredOverload
                    init(title: String, @ViewBuilder when_: () -> When) {
                        self.title = Text(title)
                        self.when_ = when_()
                    }
                }

                extension EventCard where Title == Text, When == DateResolver.Output {
                    init(title: LocalizedStringResource, when_: DateResolver.Input) {
                        self.title = Text(title)
                        self.when_ = DateResolver.resolve(when_)
                    }

                    @_disfavoredOverload
                    init(title: String, when_: DateResolver.Input) {
                        self.title = Text(title)
                        self.when_ = DateResolver.resolve(when_)
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testResolverUnlabeled() {
        assertMacroExpansion(
            """
            @Slots
            struct Row<Icon: View>: View {
                @Slot(SomeResolver.self, .unlabeled) var icon: Icon
                var body: some View { EmptyView() }
            }
            """,
            expandedSource: """
                struct Row<Icon: View>: View {
                    var icon: Icon
                    var body: some View { EmptyView() }

                    init(@ViewBuilder icon: () -> Icon) {
                        self.icon = icon()
                    }
                }

                extension Row where Icon == SomeResolver.Output {
                    init(_ icon: SomeResolver.Input) {
                        self.icon = SomeResolver.resolve(icon)
                    }
                }
                """,
            macros: testMacros
        )
    }

    // MARK: - Init limit test

    func testTooManyInitsEmitsError() {
        // 7 slots all with .text + .systemImage + optional = 5 modes each = 5^7 = 78,125 inits
        assertMacroExpansion(
            """
            @Slots
            struct Overload<A: View, B: View, C: View, D: View, E: View, F: View, G: View>: View {
                @Slot(.text, .systemImage) var a: A?
                @Slot(.text, .systemImage) var b: B?
                @Slot(.text, .systemImage) var c: C?
                @Slot(.text, .systemImage) var d: D?
                @Slot(.text, .systemImage) var e: E?
                @Slot(.text, .systemImage) var f: F?
                @Slot(.text, .systemImage) var g: G?
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
                        self.a = Optional(a())
                        self.b = Optional(b())
                        self.c = Optional(c())
                        self.d = Optional(d())
                        self.e = Optional(e())
                        self.f = Optional(f())
                        self.g = Optional(g())
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
