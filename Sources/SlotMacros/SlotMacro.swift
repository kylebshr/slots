import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - SlotMacro

public struct SlotMacro: MemberMacro, ExtensionMacro {

    // MARK: MemberMacro — base all-generic init on the struct

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let access = accessModifier(of: declaration)
        let slotsOptions = parseSlotsOptions(from: node)
        let plain = collectPlainProperties(from: declaration)
        let slots = collectSlots(from: declaration, node: node, context: context)
        guard !slots.isEmpty else { return [] }

        var entries: [ParamEntry] =
            plain.map { paramEntry(for: $0) }
            + slots.map { slot in
                let assignment =
                    slot.isOptional
                    ? "self.\(slot.name) = Optional(\(slot.name)())"
                    : "self.\(slot.name) = \(slot.name)()"
                return ParamEntry(
                    param: "@ViewBuilder \(slot.name): () -> \(slot.genericParam)",
                    assignment: assignment,
                    tier: .viewBuilder,
                    declarationIndex: slot.declarationIndex
                )
            }
        sortEntries(&entries, viewBuilderTrailing: slotsOptions.viewBuilderTrailing)
        let params = entries.map(\.param).joined(separator: ", ")
        let assignments = entries.map(\.assignment).joined(separator: "\n    ")
        let accessPrefix = access.map { "\($0) " } ?? ""

        return [
            """
            \(raw: accessPrefix)init(\(raw: params)) {
                \(raw: assignments)
            }
            """
        ]
    }

    // MARK: ExtensionMacro — constrained extensions

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let access = accessModifier(of: declaration)
        let slotsOptions = parseSlotsOptions(from: node)
        let plain = collectPlainProperties(from: declaration)
        let slots = collectSlots(from: declaration, node: node, context: context)
        guard !slots.isEmpty else { return [] }

        let initCount = initCombinationCount(for: slots)
        if initCount > maxInitCount {
            context.diagnose(
                Diagnostic(
                    node: node,
                    message: SlotError.tooManyInits(count: initCount, limit: maxInitCount)))
            return []
        }

        let groups = extensionGroups(
            for: slots, plain: plain, access: access,
            viewBuilderTrailing: slotsOptions.viewBuilderTrailing)
        return groups.compactMap { (whereClause, specs) in
            buildExtension(type: type, whereClause: whereClause, specs: specs)
        }
    }
}

// MARK: - Access modifier

/// Returns the explicit access modifier of the struct, if any (e.g. "public", "package").
/// Returns `nil` when no modifier is present (defaults to internal).
private func accessModifier(of declaration: some DeclGroupSyntax) -> String? {
    let accessKeywords: Set<String> = ["public", "package", "internal", "fileprivate", "private"]
    return declaration.as(StructDeclSyntax.self)?
        .modifiers
        .first { accessKeywords.contains($0.name.text) }?
        .name.text
}

// MARK: - Plain (non-slot) required property

/// A stored property that has no `@Slot` annotation.
/// Appears as a labeled parameter in every generated init; if it has a default value,
/// the parameter includes that default so callers can omit it.
private struct PlainProperty {
    let name: String
    let typeStr: String
    let defaultValue: String?
    let isGenericView: Bool
    let isClosure: Bool
    let needsEscaping: Bool
    let isBinding: Bool
    let declarationIndex: Int
}

/// Property wrappers that represent internal state and should be excluded from generated inits.
private let skippedPropertyWrappers: Set<String> = [
    "State", "StateObject", "ObservedObject", "Environment", "EnvironmentObject",
    "FocusState", "FocusedValue", "FocusedBinding", "AppStorage", "SceneStorage",
    "FetchRequest", "SectionedFetchRequest", "Namespace", "GestureState",
    "ScaledMetric", "UIApplicationDelegateAdaptor", "NSApplicationDelegateAdaptor",
]

private func collectPlainProperties(from declaration: some DeclGroupSyntax) -> [PlainProperty] {
    guard let structDecl = declaration.as(StructDeclSyntax.self) else { return [] }

    let genericNames = Set(
        structDecl.genericParameterClause?.parameters.map { $0.name.text } ?? []
    )

    let skippedModifiers: Set<String> = ["static", "class", "lazy"]

    return structDecl.memberBlock.members.enumerated().flatMap { memberIndex, member -> [PlainProperty] in
        guard
            let varDecl = member.decl.as(VariableDeclSyntax.self),
            // Skip static, class, and lazy properties
            !varDecl.modifiers.contains(where: { skippedModifiers.contains($0.name.text) }),
            // Not annotated with @Slot
            !varDecl.attributes.contains(where: {
                $0.as(AttributeSyntax.self)?.attributeName
                    .as(IdentifierTypeSyntax.self)?.name.text == "Slot"
            })
        else { return [] }

        // Detect property wrapper attributes
        let wrapperName = varDecl.attributes.lazy.compactMap {
            $0.as(AttributeSyntax.self)?.attributeName
                .as(IdentifierTypeSyntax.self)?.name.text
        }.first(where: { $0 == "Binding" || skippedPropertyWrappers.contains($0) })

        // Skip internal-state property wrappers entirely
        if let wrapper = wrapperName, skippedPropertyWrappers.contains(wrapper) {
            return []
        }

        let isBinding = wrapperName == "Binding"

        return varDecl.bindings.compactMap { binding -> PlainProperty? in
            guard
                binding.accessorBlock == nil,  // not computed
                let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                let typeAnnotation = binding.typeAnnotation?.type,
                // Optional generics without @Slot are still auto-slots, skip them
                !(typeAnnotation.as(OptionalTypeSyntax.self)?
                    .wrappedType.as(IdentifierTypeSyntax.self)
                    .map { genericNames.contains($0.name.text) } ?? false)
            else { return nil }

            // Required generic type without @Slot — include as @ViewBuilder closure param
            if let typeName = typeAnnotation.as(IdentifierTypeSyntax.self)?.name.text,
                genericNames.contains(typeName)
            {
                return PlainProperty(
                    name: identifier.identifier.text,
                    typeStr: typeName,
                    defaultValue: nil,
                    isGenericView: true,
                    isClosure: false,
                    needsEscaping: false,
                    isBinding: false,
                    declarationIndex: memberIndex
                )
            }

            let closure = isFunctionType(typeAnnotation)
            let optional = typeAnnotation.is(OptionalTypeSyntax.self)
            let typeStr =
                isBinding
                ? "Binding<\(typeAnnotation.trimmedDescription)>" : typeAnnotation.trimmedDescription
            let defaultValue =
                binding.initializer?.value.trimmedDescription ?? (optional ? "nil" : nil)
            return PlainProperty(
                name: identifier.identifier.text,
                typeStr: typeStr,
                defaultValue: defaultValue,
                isGenericView: false,
                isClosure: closure,
                needsEscaping: closure && !optional,
                isBinding: isBinding,
                declarationIndex: memberIndex
            )
        }
    }
}

// MARK: - Function type detection

private func isFunctionType(_ type: TypeSyntax) -> Bool {
    if type.is(FunctionTypeSyntax.self) { return true }
    if let attributed = type.as(AttributedTypeSyntax.self) {
        return isFunctionType(attributed.baseType)
    }
    if let optional = type.as(OptionalTypeSyntax.self) {
        return isFunctionType(optional.wrappedType)
    }
    if let tuple = type.as(TupleTypeSyntax.self),
        tuple.elements.count == 1,
        let inner = tuple.elements.first?.type
    {
        return isFunctionType(inner)
    }
    return false
}

// MARK: - Parsing @Slots options

private struct SlotsOptions {
    var viewBuilderTrailing = false
}

private func parseSlotsOptions(from attr: AttributeSyntax) -> SlotsOptions {
    var result = SlotsOptions()
    guard case .argumentList(let args) = attr.arguments else { return result }
    for arg in args {
        if arg.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text
            == "viewBuilderTrailing"
        {
            result.viewBuilderTrailing = true
        }
    }
    return result
}

// MARK: - Parameter ordering

/// When `viewBuilderTrailing` is enabled, parameters are sorted by tier to match
/// SwiftUI conventions: value params first, then closures, then @ViewBuilder closures last.
/// Otherwise, declaration order is preserved.
private enum ParamTier: Comparable {
    case value
    case closure
    case viewBuilder
}

private struct ParamEntry {
    let param: String
    let assignment: String
    let tier: ParamTier
    let declarationIndex: Int
}

private func sortEntries(_ entries: inout [ParamEntry], viewBuilderTrailing: Bool) {
    if viewBuilderTrailing {
        entries.sort { ($0.tier, $0.declarationIndex) < ($1.tier, $1.declarationIndex) }
    } else {
        entries.sort { $0.declarationIndex < $1.declarationIndex }
    }
}

private func paramEntry(for p: PlainProperty) -> ParamEntry {
    if p.isGenericView {
        return ParamEntry(
            param: "@ViewBuilder \(p.name): () -> \(p.typeStr)",
            assignment: "self.\(p.name) = \(p.name)()",
            tier: .viewBuilder,
            declarationIndex: p.declarationIndex
        )
    }
    let escapingPrefix = p.needsEscaping ? "@escaping " : ""
    let paramStr =
        p.defaultValue.map { "\(p.name): \(escapingPrefix)\(p.typeStr) = \($0)" }
        ?? "\(p.name): \(escapingPrefix)\(p.typeStr)"
    let assignment = p.isBinding ? "self._\(p.name) = \(p.name)" : "self.\(p.name) = \(p.name)"
    return ParamEntry(
        param: paramStr,
        assignment: assignment,
        tier: p.isClosure ? .closure : .value,
        declarationIndex: p.declarationIndex
    )
}

// MARK: - Slot descriptor

private struct SlotDescriptor {
    let name: String
    let genericParam: String
    let isOptional: Bool
    let hasText: Bool
    let hasSystemImage: Bool
    let hasEmpty: Bool
    let isUnlabeled: Bool
    let resolvers: [ResolverOption]
    let declarationIndex: Int
}

// MARK: - Mode

private enum SlotMode: Equatable {
    case generic  // caller passes any View
    case text  // fix to Text, LocalizedStringResource param, preferred
    case string  // fix to Text, String param, @_disfavoredOverload
    case systemImage  // fix to Image, {name}SystemName: String param
    case resolved(typeName: String)  // fix to Resolver.Output, Resolver.Input param
    case empty  // fix to Never, parameter omitted (stores nil)
    case emptyView  // fix to EmptyView, parameter omitted (stores EmptyView())
}

// MARK: - Init spec (one init inside an extension)

private struct InitSpec {
    let params: [String]
    let assignments: [String]
    let isDisfavored: Bool
    let access: String?
}

// MARK: - Collecting @Slot-annotated properties

private func collectSlots(
    from declaration: some DeclGroupSyntax,
    node: AttributeSyntax,
    context: some MacroExpansionContext
) -> [SlotDescriptor] {
    guard let structDecl = declaration.as(StructDeclSyntax.self) else {
        context.diagnose(Diagnostic(node: node, message: SlotError.notAStruct))
        return []
    }

    let genericNames = Set(
        structDecl.genericParameterClause?.parameters.map { $0.name.text } ?? []
    )

    let skippedModifiers: Set<String> = ["static", "class", "lazy"]

    return structDecl.memberBlock.members.enumerated().flatMap { memberIndex, member -> [SlotDescriptor] in
        guard
            let varDecl = member.decl.as(VariableDeclSyntax.self),
            // Skip static, class, and lazy properties
            !varDecl.modifiers.contains(where: { skippedModifiers.contains($0.name.text) })
        else { return [] }

        let slotAttrs = varDecl.attributes.filter {
            $0.as(AttributeSyntax.self)?.attributeName
                .as(IdentifierTypeSyntax.self)?.name.text == "Slot"
        }.compactMap { $0.as(AttributeSyntax.self) }

        let hasSlotAttr = !slotAttrs.isEmpty

        return varDecl.bindings.compactMap { binding -> SlotDescriptor? in
            guard
                binding.accessorBlock == nil,
                let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                let typeAnnotation = binding.typeAnnotation?.type
            else { return nil }

            let propertyName = identifier.identifier.text

            // Merge options from all @Slot attributes
            var options = ParsedOptions()
            for attr in slotAttrs {
                options.merge(parseSlotOptions(from: attr))
            }

            // `Icon?` — always a slot, @Slot annotation optional
            if let inner = typeAnnotation.as(OptionalTypeSyntax.self)?
                .wrappedType.as(IdentifierTypeSyntax.self)?.name.text,
                genericNames.contains(inner)
            {
                if options.flags.contains(.empty), let attr = slotAttrs.first {
                    context.diagnose(
                        Diagnostic(node: attr, message: SlotError.emptyOnOptionalSlot(propertyName)))
                }
                return SlotDescriptor(
                    name: propertyName, genericParam: inner, isOptional: true,
                    hasText: options.flags.contains(.text),
                    hasSystemImage: options.flags.contains(.systemImage),
                    hasEmpty: false,
                    isUnlabeled: options.flags.contains(.unlabeled),
                    resolvers: options.resolvers,
                    declarationIndex: memberIndex)
            }

            // `Icon` — slot only if @Slot annotated
            if let name = typeAnnotation.as(IdentifierTypeSyntax.self)?.name.text,
                genericNames.contains(name)
            {
                guard hasSlotAttr else { return nil }

                return SlotDescriptor(
                    name: propertyName, genericParam: name, isOptional: false,
                    hasText: options.flags.contains(.text),
                    hasSystemImage: options.flags.contains(.systemImage),
                    hasEmpty: options.flags.contains(.empty),
                    isUnlabeled: options.flags.contains(.unlabeled),
                    resolvers: options.resolvers,
                    declarationIndex: memberIndex)
            }

            // @Slot on a non-generic type is an error
            if let attr = slotAttrs.first {
                context.diagnose(
                    Diagnostic(node: attr, message: SlotError.cannotResolveGenericForSlot(propertyName)))
            }
            return nil
        }
    }
}

// MARK: - Parsing @Slot options

private struct OptionFlags: OptionSet {
    let rawValue: Int
    static let text = OptionFlags(rawValue: 1 << 0)
    static let systemImage = OptionFlags(rawValue: 1 << 1)
    static let unlabeled = OptionFlags(rawValue: 1 << 2)
    static let empty = OptionFlags(rawValue: 1 << 3)
}

private struct ResolverOption: Equatable {
    let typeName: String
    let isUnlabeled: Bool
}

private struct ParsedOptions {
    var flags: OptionFlags = []
    var resolvers: [ResolverOption] = []

    mutating func merge(_ other: ParsedOptions) {
        flags.formUnion(other.flags)
        resolvers.append(contentsOf: other.resolvers)
    }
}

private func parseSlotOptions(from attr: AttributeSyntax) -> ParsedOptions {
    var result = ParsedOptions()
    guard case .argumentList(let args) = attr.arguments else { return result }

    // First pass: collect resolver type names and flags
    var resolverNames: [String] = []
    for arg in args {
        let expr = arg.expression

        // Check for metatype like `SomeResolver.self`
        if let memberAccess = expr.as(MemberAccessExprSyntax.self),
            memberAccess.declName.baseName.text == "self",
            let base = memberAccess.base
        {
            resolverNames.append(base.trimmedDescription)
            continue
        }

        // Simple access like `.text`, `.systemImage`, or `.unlabeled`
        switch expr.as(MemberAccessExprSyntax.self)?.declName.baseName.text {
        case "text": result.flags.insert(.text)
        case "systemImage": result.flags.insert(.systemImage)
        case "unlabeled": result.flags.insert(.unlabeled)
        case "empty": result.flags.insert(.empty)
        default: break
        }
    }

    // Build resolver options, applying unlabeled flag to all resolvers on this attribute
    let isUnlabeled = result.flags.contains(.unlabeled)
    for name in resolverNames {
        result.resolvers.append(ResolverOption(typeName: name, isUnlabeled: isUnlabeled))
    }

    return result
}

// MARK: - Init count limit

private let maxInitCount = 512

private func initCombinationCount(for slots: [SlotDescriptor]) -> Int {
    slots.reduce(1) { count, slot in
        var modes = 1  // generic
        if slot.hasText { modes += 2 }  // text + string
        if slot.hasSystemImage { modes += 1 }
        modes += slot.resolvers.count
        if slot.isOptional { modes += 1 }  // empty (Never, nil)
        if slot.hasEmpty { modes += 1 }  // emptyView (EmptyView)
        return count * modes
    }
}

// MARK: - Cartesian product of slot modes

private func allCombinations(for slots: [SlotDescriptor]) -> [[SlotMode]] {
    slots.reduce([[SlotMode]]()) { combos, slot in
        var modes: [SlotMode] = [.generic]
        if slot.hasText {
            modes.append(.text)
            modes.append(.string)
        }
        if slot.hasSystemImage { modes.append(.systemImage) }
        for resolver in slot.resolvers {
            modes.append(.resolved(typeName: resolver.typeName))
        }
        if slot.isOptional { modes.append(.empty) }
        if slot.hasEmpty { modes.append(.emptyView) }

        guard !combos.isEmpty else { return modes.map { [$0] } }
        return combos.flatMap { existing in modes.map { existing + [$0] } }
    }
}

// MARK: - Group combinations by where clause

/// Groups all non-trivial combinations by their where-clause key so that `.text` and `.string`
/// variants for the same set of fixed generics land in the same extension.
/// When `viewBuilderTrailing` is true, parameters are sorted by tier: value params, then
/// closures, then @ViewBuilder closures. Otherwise, declaration order is preserved.
private func extensionGroups(
    for slots: [SlotDescriptor],
    plain: [PlainProperty] = [],
    access: String? = nil,
    viewBuilderTrailing: Bool = false
) -> [(whereClause: String, specs: [InitSpec])] {
    // Use an ordered structure to preserve natural combo order
    var order: [String] = []
    var groups: [String: [InitSpec]] = [:]

    for combo in allCombinations(for: slots) {
        guard combo.contains(where: { $0 != .generic }) else { continue }

        var constraints: [String] = []
        var entries: [ParamEntry] = plain.map { paramEntry(for: $0) }
        var emptyAssignments: [String] = []
        var isDisfavored = false

        for (slot, mode) in zip(slots, combo) {
            switch mode {
            case .generic:
                let genericAssignment =
                    slot.isOptional
                    ? "self.\(slot.name) = Optional(\(slot.name)())"
                    : "self.\(slot.name) = \(slot.name)()"
                entries.append(
                    ParamEntry(
                        param: "@ViewBuilder \(slot.name): () -> \(slot.genericParam)",
                        assignment: genericAssignment,
                        tier: .viewBuilder,
                        declarationIndex: slot.declarationIndex
                    ))
            case .text:
                constraints.append("\(slot.genericParam) == Text")
                let labelPrefix = slot.isUnlabeled ? "_ " : ""
                if slot.isOptional {
                    entries.append(
                        ParamEntry(
                            param: "\(labelPrefix)\(slot.name): LocalizedStringResource?",
                            assignment: "self.\(slot.name) = \(slot.name).map { Text($0) }",
                            tier: .value,
                            declarationIndex: slot.declarationIndex
                        ))
                } else {
                    entries.append(
                        ParamEntry(
                            param: "\(labelPrefix)\(slot.name): LocalizedStringResource",
                            assignment: "self.\(slot.name) = Text(\(slot.name))",
                            tier: .value,
                            declarationIndex: slot.declarationIndex
                        ))
                }
            case .string:
                constraints.append("\(slot.genericParam) == Text")
                let labelPrefix = slot.isUnlabeled ? "_ " : ""
                if slot.isOptional {
                    entries.append(
                        ParamEntry(
                            param: "\(labelPrefix)\(slot.name): String?",
                            assignment: "self.\(slot.name) = \(slot.name).map { Text($0) }",
                            tier: .value,
                            declarationIndex: slot.declarationIndex
                        ))
                } else {
                    entries.append(
                        ParamEntry(
                            param: "\(labelPrefix)\(slot.name): String",
                            assignment: "self.\(slot.name) = Text(\(slot.name))",
                            tier: .value,
                            declarationIndex: slot.declarationIndex
                        ))
                }
                isDisfavored = true
            case .systemImage:
                let paramName = "\(slot.name)SystemName"
                constraints.append("\(slot.genericParam) == Image")
                if slot.isOptional {
                    entries.append(
                        ParamEntry(
                            param: "\(paramName): String?",
                            assignment: "self.\(slot.name) = \(paramName).map { Image(systemName: $0) }",
                            tier: .value,
                            declarationIndex: slot.declarationIndex
                        ))
                } else {
                    entries.append(
                        ParamEntry(
                            param: "\(paramName): String",
                            assignment: "self.\(slot.name) = Image(systemName: \(paramName))",
                            tier: .value,
                            declarationIndex: slot.declarationIndex
                        ))
                }
            case .resolved(let typeName):
                constraints.append("\(slot.genericParam) == \(typeName).Output")
                let isUnlabeled =
                    slot.resolvers.first(where: { $0.typeName == typeName })?.isUnlabeled ?? false
                let labelPrefix = isUnlabeled ? "_ " : ""
                let resolve = "\(typeName).resolve(\(slot.name))"
                let param =
                    slot.isOptional
                    ? "\(labelPrefix)\(slot.name): \(typeName).Input?"
                    : "\(labelPrefix)\(slot.name): \(typeName).Input"
                let assignment =
                    slot.isOptional
                    ? "self.\(slot.name) = \(slot.name).map { \(typeName).resolve($0) }"
                    : "self.\(slot.name) = \(resolve)"
                entries.append(
                    ParamEntry(
                        param: param,
                        assignment: assignment,
                        tier: .value,
                        declarationIndex: slot.declarationIndex
                    ))
            case .empty:
                constraints.append("\(slot.genericParam) == Never")
                emptyAssignments.append("self.\(slot.name) = nil")
            case .emptyView:
                constraints.append("\(slot.genericParam) == EmptyView")
                emptyAssignments.append("self.\(slot.name) = EmptyView()")
            }
        }

        sortEntries(&entries, viewBuilderTrailing: viewBuilderTrailing)

        let key = constraints.joined(separator: ", ")
        let spec = InitSpec(
            params: entries.map(\.param),
            assignments: entries.map(\.assignment) + emptyAssignments,
            isDisfavored: isDisfavored,
            access: access
        )

        if groups[key] == nil {
            order.append(key)
            groups[key] = []
        }
        groups[key]!.append(spec)
    }

    return order.map { key in (whereClause: key, specs: groups[key]!) }
}

// MARK: - Building an extension

private func buildExtension(
    type: some TypeSyntaxProtocol,
    whereClause: String,
    specs: [InitSpec]
) -> ExtensionDeclSyntax? {
    let body = specs.map { formatInit($0) }.joined(separator: "\n\n")

    let source: DeclSyntax = """
        extension \(type.trimmed) where \(raw: whereClause) {
        \(raw: body)
        }
        """
    return source.as(ExtensionDeclSyntax.self)
}

private func formatInit(_ spec: InitSpec) -> String {
    let paramStr = spec.params.joined(separator: ", ")
    let assignLines = spec.assignments.map { "        \($0)" }.joined(separator: "\n")
    let attr = spec.isDisfavored ? "    @_disfavoredOverload\n" : ""
    let accessPrefix = spec.access.map { "\($0) " } ?? ""
    return "\(attr)    \(accessPrefix)init(\(paramStr)) {\n\(assignLines)\n    }"
}

// MARK: - Diagnostics

enum SlotError: Error, CustomStringConvertible {
    case notAStruct
    case cannotResolveGenericForSlot(String)
    case tooManyInits(count: Int, limit: Int)
    case emptyOnOptionalSlot(String)

    var description: String {
        switch self {
        case .notAStruct:
            return "@Slots can only be applied to a struct"
        case .cannotResolveGenericForSlot(let name):
            return "@Slot on '\(name)': property type must be one of the struct's generic parameters"
        case .tooManyInits(let count, let limit):
            return
                "@Slots would generate \(count) initializers (limit is \(limit)); reduce the number of slots or slot options to stay within the limit"
        case .emptyOnOptionalSlot(let name):
            return
                "@Slot(.empty) on '\(name)': .empty cannot be used on optional slots; optional slots already support omission"
        }
    }
}

extension SlotError: DiagnosticMessage {
    var message: String { description }
    var diagnosticID: MessageID { MessageID(domain: "Slot", id: "\(self)") }
    var severity: DiagnosticSeverity { .error }
}
