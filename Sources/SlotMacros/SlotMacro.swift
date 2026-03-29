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

        let params =
            (plain.map { p in
                if p.isGenericView {
                    return "@ViewBuilder \(p.name): () -> \(p.typeStr)"
                }
                return p.defaultValue.map { "\(p.name): \(p.typeStr) = \($0)" } ?? "\(p.name): \(p.typeStr)"
            }
            + slots.map { "@ViewBuilder \($0.name): () -> \($0.genericParam)" })
            .joined(separator: ", ")
        let assignments =
            (plain.map { p in
                p.isGenericView ? "self.\(p.name) = \(p.name)()" : "self.\(p.name) = \(p.name)"
            }
            + slots.map { "self.\($0.name) = \($0.name)()" })
            .joined(separator: "\n    ")
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
                    isGenericView: true
                )
            }

            return PlainProperty(
                name: identifier.identifier.text,
                typeStr: typeAnnotation.trimmedDescription,
                defaultValue: binding.initializer?.value.trimmedDescription,
                isGenericView: false
            )
        }
    }
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
/// Plain required properties are prepended to every init's parameter list.
private func extensionGroups(
    for slots: [SlotDescriptor],
    plain: [PlainProperty] = [],
    access: String? = nil
) -> [(whereClause: String, specs: [InitSpec])] {
    let plainParams = plain.map { p in
        if p.isGenericView {
            return "@ViewBuilder \(p.name): () -> \(p.typeStr)"
        }
        return p.defaultValue.map { "\(p.name): \(p.typeStr) = \($0)" } ?? "\(p.name): \(p.typeStr)"
    }
    let plainAssignments = plain.map { p in
        p.isGenericView ? "self.\(p.name) = \(p.name)()" : "self.\(p.name) = \(p.name)"
    }

    // Use an ordered structure to preserve natural combo order
    var order: [String] = []
    var groups: [String: [InitSpec]] = [:]

    for combo in allCombinations(for: slots) {
        guard combo.contains(where: { $0 != .generic }) else { continue }

        var constraints: [String] = []
        var params: [String] = plainParams
        var assignments: [String] = plainAssignments
        var isDisfavored = false

        for (slot, mode) in zip(slots, combo) {
            switch mode {
            case .generic:
                params.append("@ViewBuilder \(slot.name): () -> \(slot.genericParam)")
                assignments.append("self.\(slot.name) = \(slot.name)()")
            case .text:
                constraints.append("\(slot.genericParam) == Text")
                if slot.isOptional {
                    params.append("\(slot.name): LocalizedStringKey?")
                    assignments.append("self.\(slot.name) = \(slot.name).map { Text($0) }")
                } else {
                    params.append("\(slot.name): LocalizedStringKey")
                    assignments.append("self.\(slot.name) = Text(\(slot.name))")
                }
            case .string:
                constraints.append("\(slot.genericParam) == Text")
                if slot.isOptional {
                    params.append("\(slot.name): String?")
                    assignments.append("self.\(slot.name) = \(slot.name).map { Text($0) }")
                } else {
                    params.append("\(slot.name): String")
                    assignments.append("self.\(slot.name) = Text(\(slot.name))")
                }
                isDisfavored = true
            case .image:
                let paramName = "\(slot.name)SystemName"
                constraints.append("\(slot.genericParam) == Image")
                if slot.isOptional {
                    params.append("\(paramName): String?")
                    assignments.append("self.\(slot.name) = \(paramName).map { Image(systemName: $0) }")
                } else {
                    params.append("\(paramName): String")
                    assignments.append("self.\(slot.name) = Image(systemName: \(paramName))")
                }
            case .empty:
                constraints.append("\(slot.genericParam) == Never")
                assignments.append("self.\(slot.name) = nil")
            }
        }

        let key = constraints.joined(separator: ", ")
        let spec = InitSpec(params: params, assignments: assignments, isDisfavored: isDisfavored, access: access)

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

    var description: String {
        switch self {
        case .notAStruct:
            return "@Slots can only be applied to a struct"
        case .cannotResolveGenericForSlot(let name):
            return "@Slot on '\(name)': property type must be one of the struct's generic parameters"
        }
    }
}

extension SlotError: DiagnosticMessage {
    var message: String { description }
    var diagnosticID: MessageID { MessageID(domain: "Slot", id: "\(self)") }
    var severity: DiagnosticSeverity { .error }
}
