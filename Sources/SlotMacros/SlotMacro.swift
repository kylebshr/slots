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
        let slotsOptions = parseSlotsOptions(from: node)
        let access = slotsOptions.internalInit ? nil : accessModifier(of: declaration)
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
        sortEntries(&entries, trailingViewBuilders: slotsOptions.trailingViewBuilders)
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
        let slotsOptions = parseSlotsOptions(from: node)
        let access = slotsOptions.internalInit ? nil : accessModifier(of: declaration)
        let plain = collectPlainProperties(from: declaration)
        let slots = collectSlots(from: declaration, node: node, context: context)
        guard !slots.isEmpty else { return [] }

        if let shared = sharedGenericParameter(slots: slots, plain: plain) {
            context.diagnose(
                Diagnostic(
                    node: node,
                    message: SlotError.sharedGenericParameter(shared.genericParam, properties: shared.properties)))
            return []
        }

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
            trailingViewBuilders: slotsOptions.trailingViewBuilders)
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
    let modifier = declaration.as(StructDeclSyntax.self)?
        .modifiers
        .first { accessKeywords.contains($0.name.text) }?
        .name.text
    // A `private init` would be private to the struct itself, so the rest of the file couldn't call it.
    return modifier == "private" ? "fileprivate" : modifier
}

// MARK: - Generic parameters

/// Names of the struct's generic parameters that are constrained to `View`,
/// either in the parameter clause (`<Icon: View>`) or in a where clause (`where Icon: View`).
private func viewGenericNames(of structDecl: StructDeclSyntax) -> Set<String> {
    var names: Set<String> = []
    for param in structDecl.genericParameterClause?.parameters ?? [] {
        if let inherited = param.inheritedType, isViewConstraint(inherited) {
            names.insert(param.name.text)
        }
    }
    for requirement in structDecl.genericWhereClause?.requirements ?? [] {
        if case .conformanceRequirement(let conformance) = requirement.requirement,
            let name = conformance.leftType.as(IdentifierTypeSyntax.self)?.name.text,
            isViewConstraint(conformance.rightType)
        {
            names.insert(name)
        }
    }
    return names
}

private func isViewConstraint(_ type: TypeSyntax) -> Bool {
    if let composition = type.as(CompositionTypeSyntax.self) {
        return composition.elements.contains { isViewConstraint($0.type) }
    }
    if let member = type.as(MemberTypeSyntax.self) {
        return member.name.text == "View"
    }
    return type.as(IdentifierTypeSyntax.self)?.name.text == "View"
}

// MARK: - Attributes

private func attributeNames(of varDecl: VariableDeclSyntax) -> [String] {
    varDecl.attributes.compactMap {
        $0.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.name.text
    }
}

/// A `let` with an initial value can't be assigned again, so it's excluded from the init.
private func isInitializedConstant(_ varDecl: VariableDeclSyntax, _ binding: PatternBindingSyntax) -> Bool {
    varDecl.bindingSpecifier.tokenKind == .keyword(.let) && binding.initializer != nil
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
    let isViewBuilder: Bool
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

    let viewGenerics = viewGenericNames(of: structDecl)

    let skippedModifiers: Set<String> = ["static", "class", "lazy"]

    return structDecl.memberBlock.members.enumerated().flatMap { memberIndex, member -> [PlainProperty] in
        guard
            let varDecl = member.decl.as(VariableDeclSyntax.self),
            // Skip static, class, and lazy properties
            !varDecl.modifiers.contains(where: { skippedModifiers.contains($0.name.text) })
        else { return [] }

        let attributes = attributeNames(of: varDecl)

        // Skip @Slot properties and internal-state property wrappers
        if attributes.contains(where: { $0 == "Slot" || skippedPropertyWrappers.contains($0) }) {
            return []
        }

        let isBinding = attributes.contains("Binding")
        let isViewBuilder = attributes.contains("ViewBuilder")

        return varDecl.bindings.compactMap { binding -> PlainProperty? in
            guard
                binding.accessorBlock == nil,  // not computed
                !isInitializedConstant(varDecl, binding),
                let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                let typeAnnotation = binding.typeAnnotation?.type
            else { return nil }

            if !isBinding {
                // Optional View generics without @Slot are still auto-slots, skip them
                if let inner = typeAnnotation.as(OptionalTypeSyntax.self)?
                    .wrappedType.as(IdentifierTypeSyntax.self)?.name.text,
                    viewGenerics.contains(inner)
                {
                    return nil
                }

                // Required View generic without @Slot — include as @ViewBuilder closure param
                if let typeName = typeAnnotation.as(IdentifierTypeSyntax.self)?.name.text,
                    viewGenerics.contains(typeName)
                {
                    return PlainProperty(
                        name: identifier.identifier.text,
                        typeStr: typeName,
                        defaultValue: nil,
                        isGenericView: true,
                        isClosure: false,
                        needsEscaping: false,
                        isBinding: false,
                        isViewBuilder: false,
                        declarationIndex: memberIndex
                    )
                }
            }

            let closure = !isBinding && isFunctionType(typeAnnotation)
            let optional = typeAnnotation.is(OptionalTypeSyntax.self)
            let typeStr =
                isBinding
                ? "Binding<\(typeAnnotation.trimmedDescription)>" : typeAnnotation.trimmedDescription
            // `Binding<T?>` can't be defaulted to `nil`
            let defaultValue =
                binding.initializer?.value.trimmedDescription ?? (optional && !isBinding ? "nil" : nil)
            return PlainProperty(
                name: identifier.identifier.text,
                typeStr: typeStr,
                defaultValue: defaultValue,
                isGenericView: false,
                isClosure: closure,
                needsEscaping: closure && !optional,
                isBinding: isBinding,
                isViewBuilder: isViewBuilder && closure,
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
    var trailingViewBuilders = false
    var internalInit = false
}

private func parseSlotsOptions(from attr: AttributeSyntax) -> SlotsOptions {
    var result = SlotsOptions()
    guard case .argumentList(let args) = attr.arguments else { return result }
    for arg in args {
        switch arg.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text {
        case "trailingViewBuilders": result.trailingViewBuilders = true
        case "internalInit": result.internalInit = true
        default: break
        }
    }
    return result
}

// MARK: - Parameter ordering

/// When `trailingViewBuilders` is enabled, parameters are sorted by tier to match
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

private func sortEntries(_ entries: inout [ParamEntry], trailingViewBuilders: Bool) {
    if trailingViewBuilders {
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
    let viewBuilderPrefix = p.isViewBuilder ? "@ViewBuilder " : ""
    let escapingPrefix = p.needsEscaping ? "@escaping " : ""
    let paramStr =
        p.defaultValue.map { "\(viewBuilderPrefix)\(p.name): \(escapingPrefix)\(p.typeStr) = \($0)" }
        ?? "\(viewBuilderPrefix)\(p.name): \(escapingPrefix)\(p.typeStr)"
    let assignment = p.isBinding ? "self._\(p.name) = \(p.name)" : "self.\(p.name) = \(p.name)"
    let tier: ParamTier = p.isViewBuilder ? .viewBuilder : p.isClosure ? .closure : .value
    return ParamEntry(
        param: paramStr,
        assignment: assignment,
        tier: tier,
        declarationIndex: p.declarationIndex
    )
}

// MARK: - Slot descriptor

private struct SlotDescriptor {
    let name: String
    let genericParam: String
    let isOptional: Bool
    let hasEmpty: Bool
    let variants: [SlotVariant]
    let declarationIndex: Int
}

/// A convenience init variant requested by an `@Slot` attribute.
/// `isUnlabeled` comes from the same attribute, so each attribute labels only its own variants.
private struct SlotVariant {
    enum Kind: Equatable {
        case text
        case systemImage
        case resolver(typeName: String)
    }

    let kind: Kind
    let isUnlabeled: Bool
}

// MARK: - Mode

private enum SlotMode: Equatable {
    case generic  // caller passes any View
    case text(isUnlabeled: Bool)  // fix to Text, LocalizedStringResource param, preferred
    case string(isUnlabeled: Bool)  // fix to Text, String param, @_disfavoredOverload
    case systemImage  // fix to Image, {name}SystemName: String param
    case resolved(typeName: String, isUnlabeled: Bool)  // fix to Resolver.Output, Resolver.Input param
    case empty  // fix to Never, parameter omitted (stores nil)
    case emptyView  // fix to EmptyView, parameter omitted (stores EmptyView())
}

private func modes(for slot: SlotDescriptor) -> [SlotMode] {
    var modes: [SlotMode] = [.generic]
    for variant in slot.variants {
        switch variant.kind {
        case .text:
            modes += [.text(isUnlabeled: variant.isUnlabeled), .string(isUnlabeled: variant.isUnlabeled)]
        case .systemImage:
            modes.append(.systemImage)
        case .resolver(let typeName):
            modes.append(.resolved(typeName: typeName, isUnlabeled: variant.isUnlabeled))
        }
    }
    if slot.isOptional { modes.append(.empty) }
    if slot.hasEmpty { modes.append(.emptyView) }
    return modes
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
    let viewGenerics = viewGenericNames(of: structDecl)

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

        // Bindings and internal-state property wrappers are never automatic slots
        if !hasSlotAttr,
            attributeNames(of: varDecl).contains(where: { $0 == "Binding" || skippedPropertyWrappers.contains($0) })
        {
            return []
        }

        return varDecl.bindings.compactMap { binding -> SlotDescriptor? in
            guard
                binding.accessorBlock == nil,
                !isInitializedConstant(varDecl, binding),
                let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                let typeAnnotation = binding.typeAnnotation?.type
            else { return nil }

            let propertyName = identifier.identifier.text

            // Each @Slot attribute adds its own variants; `.empty` applies to the whole slot
            var variants: [SlotVariant] = []
            var emptyAttr: AttributeSyntax?
            for attr in slotAttrs {
                let options = parseSlotOptions(from: attr)
                if options.hasEmpty { emptyAttr = attr }
                // `.unlabeled` only affects text and resolver variants
                if options.isUnlabeled, !options.variants.contains(where: { $0 != .systemImage }) {
                    context.diagnose(
                        Diagnostic(node: attr, message: SlotError.unlabeledWithoutVariant(propertyName)))
                }
                for kind in options.variants {
                    if variants.contains(where: { $0.kind == kind }) {
                        context.diagnose(
                            Diagnostic(node: attr, message: SlotError.duplicateVariant(propertyName)))
                    } else {
                        variants.append(SlotVariant(kind: kind, isUnlabeled: options.isUnlabeled))
                    }
                }
            }

            // `Icon?` — a slot when `Icon` is constrained to `View` or the property is @Slot annotated
            if let inner = typeAnnotation.as(OptionalTypeSyntax.self)?
                .wrappedType.as(IdentifierTypeSyntax.self)?.name.text,
                genericNames.contains(inner),
                hasSlotAttr || viewGenerics.contains(inner)
            {
                if let emptyAttr {
                    context.diagnose(
                        Diagnostic(node: emptyAttr, message: SlotError.emptyOnOptionalSlot(propertyName)))
                }
                return SlotDescriptor(
                    name: propertyName, genericParam: inner, isOptional: true,
                    hasEmpty: false, variants: variants,
                    declarationIndex: memberIndex)
            }

            // `Icon` — slot only if @Slot annotated
            if let name = typeAnnotation.as(IdentifierTypeSyntax.self)?.name.text,
                genericNames.contains(name)
            {
                guard hasSlotAttr else { return nil }

                return SlotDescriptor(
                    name: propertyName, genericParam: name, isOptional: false,
                    hasEmpty: emptyAttr != nil, variants: variants,
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

/// The options written on a single `@Slot` attribute.
private struct SlotAttributeOptions {
    var variants: [SlotVariant.Kind] = []
    var isUnlabeled = false
    var hasEmpty = false
}

private func parseSlotOptions(from attr: AttributeSyntax) -> SlotAttributeOptions {
    var result = SlotAttributeOptions()
    guard case .argumentList(let args) = attr.arguments else { return result }

    for arg in args {
        guard let memberAccess = arg.expression.as(MemberAccessExprSyntax.self) else { continue }

        // Metatype like `SomeResolver.self`
        if memberAccess.declName.baseName.text == "self", let base = memberAccess.base {
            result.variants.append(.resolver(typeName: base.trimmedDescription))
            continue
        }

        // Simple access like `.text`, `.systemImage`, or `.unlabeled`
        switch memberAccess.declName.baseName.text {
        case "text": result.variants.append(.text)
        case "systemImage": result.variants.append(.systemImage)
        case "unlabeled": result.isUnlabeled = true
        case "empty": result.hasEmpty = true
        default: break
        }
    }

    return result
}

// MARK: - Shared generic parameters

/// Each convenience init fixes a slot's generic parameter to one type (`Text`, `Never`, ...),
/// which would contradict any other property declared with that same parameter.
private func sharedGenericParameter(
    slots: [SlotDescriptor],
    plain: [PlainProperty]
) -> (genericParam: String, properties: [String])? {
    for slot in slots {
        let users =
            slots.filter { $0.genericParam == slot.genericParam }.map { ($0.declarationIndex, $0.name) }
            + plain.filter { $0.typeStr == slot.genericParam || $0.typeStr == "\(slot.genericParam)?" }
            .map { ($0.declarationIndex, $0.name) }
        if users.count > 1 {
            return (slot.genericParam, users.sorted { $0.0 < $1.0 }.map(\.1))
        }
    }
    return nil
}

// MARK: - Init count limit

private let maxInitCount = 512

private func initCombinationCount(for slots: [SlotDescriptor]) -> Int {
    slots.reduce(1) { $0 * modes(for: $1).count }
}

// MARK: - Cartesian product of slot modes

private func allCombinations(for slots: [SlotDescriptor]) -> [[SlotMode]] {
    slots.reduce([[SlotMode]]()) { combos, slot in
        let modes = modes(for: slot)
        guard !combos.isEmpty else { return modes.map { [$0] } }
        return combos.flatMap { existing in modes.map { existing + [$0] } }
    }
}

// MARK: - Group combinations by where clause

/// Groups all non-trivial combinations by their where-clause key so that `.text` and `.string`
/// variants for the same set of fixed generics land in the same extension.
/// When `trailingViewBuilders` is true, parameters are sorted by tier: value params, then
/// closures, then @ViewBuilder closures. Otherwise, declaration order is preserved.
private func extensionGroups(
    for slots: [SlotDescriptor],
    plain: [PlainProperty] = [],
    access: String? = nil,
    trailingViewBuilders: Bool = false
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
            case .text(let isUnlabeled):
                constraints.append("\(slot.genericParam) == Text")
                let labelPrefix = isUnlabeled ? "_ " : ""
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
            case .string(let isUnlabeled):
                constraints.append("\(slot.genericParam) == Text")
                let labelPrefix = isUnlabeled ? "_ " : ""
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
            case .resolved(let typeName, let isUnlabeled):
                constraints.append("\(slot.genericParam) == \(typeName).Output")
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

        sortEntries(&entries, trailingViewBuilders: trailingViewBuilders)

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
    case unlabeledWithoutVariant(String)
    case duplicateVariant(String)
    case sharedGenericParameter(String, properties: [String])

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
        case .unlabeledWithoutVariant(let name):
            return
                "@Slot on '\(name)': .unlabeled only applies to .text and resolvers in the same @Slot attribute"
        case .duplicateVariant(let name):
            return "@Slot on '\(name)': each option or resolver can only appear once per property"
        case .sharedGenericParameter(let param, let properties):
            let names = properties.map { "'\($0)'" }.joined(separator: ", ")
            return
                "Generic parameter '\(param)' is used by \(names); each slot needs its own generic parameter"
        }
    }
}

extension SlotError: DiagnosticMessage {
    var message: String { description }
    var diagnosticID: MessageID { MessageID(domain: "Slot", id: "\(self)") }
    var severity: DiagnosticSeverity { .error }
}
