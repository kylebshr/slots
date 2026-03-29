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
        let plain = collectPlainProperties(from: declaration)
        let slots = try collectSlots(from: declaration)
        guard !slots.isEmpty else { return [] }

        var entries =
            plain.map { paramEntry(for: $0) }
            + slots.map {
                ParamEntry(
                    param: "@ViewBuilder \($0.name): () -> \($0.genericParam)",
                    assignment: "self.\($0.name) = \($0.name)()",
                    tier: .viewBuilder
                )
            }
        entries.sort { $0.tier < $1.tier }
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
        let plain = collectPlainProperties(from: declaration)
        let slots = try collectSlots(from: declaration)
        guard !slots.isEmpty else { return [] }

        let initCount = initCombinationCount(for: slots)
        if initCount > maxInitCount {
            context.diagnose(
                Diagnostic(
                    node: node,
                    message: SlotError.tooManyInits(count: initCount, limit: maxInitCount)))
            return []
        }

        let groups = extensionGroups(for: slots, plain: plain, access: access)
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
}

private func collectPlainProperties(from declaration: some DeclGroupSyntax) -> [PlainProperty] {
    guard let structDecl = declaration.as(StructDeclSyntax.self) else { return [] }

    let genericNames = Set(
        structDecl.genericParameterClause?.parameters.map { $0.name.text } ?? []
    )

    return structDecl.memberBlock.members.flatMap { member -> [PlainProperty] in
        guard
            let varDecl = member.decl.as(VariableDeclSyntax.self),
            // Not annotated with @Slot
            !varDecl.attributes.contains(where: {
                $0.as(AttributeSyntax.self)?.attributeName
                    .as(IdentifierTypeSyntax.self)?.name.text == "Slot"
            })
        else { return [] }

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
                    needsEscaping: false
                )
            }

            let closure = isFunctionType(typeAnnotation)
            let optional = typeAnnotation.is(OptionalTypeSyntax.self)
            return PlainProperty(
                name: identifier.identifier.text,
                typeStr: typeAnnotation.trimmedDescription,
                defaultValue: binding.initializer?.value.trimmedDescription,
                isGenericView: false,
                isClosure: closure,
                needsEscaping: closure && !optional
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

// MARK: - Parameter ordering

/// Parameters are sorted by tier to match SwiftUI conventions:
/// value params first, then closures, then @ViewBuilder closures last.
private enum ParamTier: Comparable {
    case value
    case closure
    case viewBuilder
}

private struct ParamEntry {
    let param: String
    let assignment: String
    let tier: ParamTier
}

private func paramEntry(for p: PlainProperty) -> ParamEntry {
    if p.isGenericView {
        return ParamEntry(
            param: "@ViewBuilder \(p.name): () -> \(p.typeStr)",
            assignment: "self.\(p.name) = \(p.name)()",
            tier: .viewBuilder
        )
    }
    let escapingPrefix = p.needsEscaping ? "@escaping " : ""
    let paramStr =
        p.defaultValue.map { "\(p.name): \(escapingPrefix)\(p.typeStr) = \($0)" }
        ?? "\(p.name): \(escapingPrefix)\(p.typeStr)"
    return ParamEntry(
        param: paramStr,
        assignment: "self.\(p.name) = \(p.name)",
        tier: p.isClosure ? .closure : .value
    )
}

// MARK: - Slot descriptor

private struct SlotDescriptor {
    let name: String
    let genericParam: String
    let isOptional: Bool
    let hasText: Bool
    let hasImage: Bool
}

// MARK: - Mode

private enum SlotMode: Equatable {
    case generic  // caller passes any View
    case text  // fix to Text, LocalizedStringKey param, preferred
    case string  // fix to Text, String param, @_disfavoredOverload
    case image  // fix to Image, {name}SystemName: String param
    case empty  // fix to Never, parameter omitted (stores nil)
}

// MARK: - Init spec (one init inside an extension)

private struct InitSpec {
    let params: [String]
    let assignments: [String]
    let isDisfavored: Bool
    let access: String?
}

// MARK: - Collecting @Slot-annotated properties

private func collectSlots(from declaration: some DeclGroupSyntax) throws -> [SlotDescriptor] {
    guard let structDecl = declaration.as(StructDeclSyntax.self) else {
        throw SlotError.notAStruct
    }

    let genericNames = Set(
        structDecl.genericParameterClause?.parameters.map { $0.name.text } ?? []
    )

    return try structDecl.memberBlock.members.flatMap { member -> [SlotDescriptor] in
        guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { return [] }

        let slotAttr = varDecl.attributes.first(where: {
            $0.as(AttributeSyntax.self)?.attributeName
                .as(IdentifierTypeSyntax.self)?.name.text == "Slot"
        })?.as(AttributeSyntax.self)

        return try varDecl.bindings.compactMap { binding -> SlotDescriptor? in
            guard
                binding.accessorBlock == nil,
                let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                let typeAnnotation = binding.typeAnnotation?.type
            else { return nil }

            let propertyName = identifier.identifier.text

            // `Icon?` — always a slot, @Slot annotation optional
            if let inner = typeAnnotation.as(OptionalTypeSyntax.self)?
                .wrappedType.as(IdentifierTypeSyntax.self)?.name.text,
                genericNames.contains(inner)
            {
                let options = slotAttr.map { parseSlotOptions(from: $0) } ?? ParsedOptions()

                return SlotDescriptor(
                    name: propertyName, genericParam: inner, isOptional: true, hasText: options.contains(.text),
                    hasImage: options.contains(.image))
            }

            // `Icon` — slot only if @Slot annotated
            if let name = typeAnnotation.as(IdentifierTypeSyntax.self)?.name.text,
                genericNames.contains(name)
            {
                guard slotAttr != nil else { return nil }
                let options = parseSlotOptions(from: slotAttr!)

                return SlotDescriptor(
                    name: propertyName, genericParam: name, isOptional: false, hasText: options.contains(.text),
                    hasImage: options.contains(.image))
            }

            // @Slot on a non-generic type is an error
            if slotAttr != nil { throw SlotError.cannotResolveGenericForSlot(propertyName) }
            return nil
        }
    }
}

// MARK: - Parsing @Slot options

private struct ParsedOptions: OptionSet {
    let rawValue: Int
    static let text = ParsedOptions(rawValue: 1 << 0)
    static let image = ParsedOptions(rawValue: 1 << 1)
}

private func parseSlotOptions(from attr: AttributeSyntax) -> ParsedOptions {
    var result = ParsedOptions()
    guard case .argumentList(let args) = attr.arguments else { return result }
    for arg in args {
        switch arg.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text {
        case "text": result.insert(.text)
        case "image": result.insert(.image)
        default: break
        }
    }
    return result
}

// MARK: - Init count limit

private let maxInitCount = 512

private func initCombinationCount(for slots: [SlotDescriptor]) -> Int {
    slots.reduce(1) { count, slot in
        var modes = 1  // generic
        if slot.hasText { modes += 2 }  // text + string
        if slot.hasImage { modes += 1 }
        if slot.isOptional { modes += 1 }  // empty
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
        if slot.hasImage { modes.append(.image) }
        if slot.isOptional { modes.append(.empty) }

        guard !combos.isEmpty else { return modes.map { [$0] } }
        return combos.flatMap { existing in modes.map { existing + [$0] } }
    }
}

// MARK: - Group combinations by where clause

/// Groups all non-trivial combinations by their where-clause key so that `.text` and `.string`
/// variants for the same set of fixed generics land in the same extension.
/// Parameters are sorted by tier: value params, then closures, then @ViewBuilder closures.
private func extensionGroups(
    for slots: [SlotDescriptor],
    plain: [PlainProperty] = [],
    access: String? = nil
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
                entries.append(
                    ParamEntry(
                        param: "@ViewBuilder \(slot.name): () -> \(slot.genericParam)",
                        assignment: "self.\(slot.name) = \(slot.name)()",
                        tier: .viewBuilder
                    ))
            case .text:
                constraints.append("\(slot.genericParam) == Text")
                if slot.isOptional {
                    entries.append(
                        ParamEntry(
                            param: "\(slot.name): LocalizedStringKey?",
                            assignment: "self.\(slot.name) = \(slot.name).map { Text($0) }",
                            tier: .value
                        ))
                } else {
                    entries.append(
                        ParamEntry(
                            param: "\(slot.name): LocalizedStringKey",
                            assignment: "self.\(slot.name) = Text(\(slot.name))",
                            tier: .value
                        ))
                }
            case .string:
                constraints.append("\(slot.genericParam) == Text")
                if slot.isOptional {
                    entries.append(
                        ParamEntry(
                            param: "\(slot.name): String?",
                            assignment: "self.\(slot.name) = \(slot.name).map { Text($0) }",
                            tier: .value
                        ))
                } else {
                    entries.append(
                        ParamEntry(
                            param: "\(slot.name): String",
                            assignment: "self.\(slot.name) = Text(\(slot.name))",
                            tier: .value
                        ))
                }
                isDisfavored = true
            case .image:
                let paramName = "\(slot.name)SystemName"
                constraints.append("\(slot.genericParam) == Image")
                if slot.isOptional {
                    entries.append(
                        ParamEntry(
                            param: "\(paramName): String?",
                            assignment: "self.\(slot.name) = \(paramName).map { Image(systemName: $0) }",
                            tier: .value
                        ))
                } else {
                    entries.append(
                        ParamEntry(
                            param: "\(paramName): String",
                            assignment: "self.\(slot.name) = Image(systemName: \(paramName))",
                            tier: .value
                        ))
                }
            case .empty:
                constraints.append("\(slot.genericParam) == Never")
                emptyAssignments.append("self.\(slot.name) = nil")
            }
        }

        entries.sort { $0.tier < $1.tier }

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

    var description: String {
        switch self {
        case .notAStruct:
            return "@Slots can only be applied to a struct"
        case .cannotResolveGenericForSlot(let name):
            return "@Slot on '\(name)': property type must be one of the struct's generic parameters"
        case .tooManyInits(let count, let limit):
            return
                "@Slots would generate \(count) initializers (limit is \(limit)); reduce the number of slots or slot options to stay within the limit"
        }
    }
}

extension SlotError: DiagnosticMessage {
    var message: String { description }
    var diagnosticID: MessageID { MessageID(domain: "Slot", id: "\(self)") }
    var severity: DiagnosticSeverity { .error }
}
