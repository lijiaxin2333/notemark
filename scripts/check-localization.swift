// Checks that every translation table covers every key in L10n.swift, with
// the same number of arguments. Usage: swift scripts/check-localization.swift
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let source = try String(contentsOf: root.appendingPathComponent("Sources/NoteMark/App/L10n.swift"), encoding: .utf8)
let commands = try String(contentsOf: root.appendingPathComponent("Sources/NoteMarkCore/Slash/SlashCommand.swift"), encoding: .utf8)

/// Keys from `String(localized: "key", defaultValue: "…")`, with the number of interpolated arguments.
var expected: [String: Int] = [:]
let entry = try NSRegularExpression(pattern: #"String\(localized: "([^"]+)",\s*defaultValue: "((?:[^"\\]|\\.)*)""#)
for match in entry.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
    let key = String(source[Range(match.range(at: 1), in: source)!])
    let value = String(source[Range(match.range(at: 2), in: source)!])
    expected[key] = value.components(separatedBy: "\\(").count - 1
}
let commandID = try NSRegularExpression(pattern: #"\.init\(id: "([a-z]+)""#)
for match in commandID.matches(in: commands, range: NSRange(commands.startIndex..., in: commands)) {
    let id = String(commands[Range(match.range(at: 1), in: commands)!])
    expected["slash.\(id).title"] = 0
    expected["slash.\(id).detail"] = 0
}
guard expected.count > 50 else { fatalError("Found only \(expected.count) keys; the parser is out of date.") }

var failures: [String] = []
let resources = root.appendingPathComponent("Packaging/Resources")
let languages = try FileManager.default.contentsOfDirectory(atPath: resources.path).filter { $0.hasSuffix(".lproj") }.sorted()
for language in languages {
    let table = resources.appendingPathComponent(language).appendingPathComponent("Localizable.strings")
    // English is the development language; its text is the default value in code.
    guard FileManager.default.fileExists(atPath: table.path) else { continue }
    guard let strings = NSDictionary(contentsOf: table) as? [String: String] else {
        failures.append("\(language): cannot read Localizable.strings"); continue
    }
    for (key, arguments) in expected.sorted(by: { $0.key < $1.key }) {
        guard let value = strings[key] else { failures.append("\(language): missing \(key)"); continue }
        let specifier = try NSRegularExpression(pattern: #"%(\d+\$)?@"#)
        let found = specifier.numberOfMatches(in: value, range: NSRange(value.startIndex..., in: value))
        if found != arguments { failures.append("\(language): \(key) has \(found) of \(arguments) arguments") }
    }
    for key in Set(strings.keys).subtracting(expected.keys).sorted() { failures.append("\(language): unused \(key)") }
}
if failures.isEmpty {
    print("Localization check passed: \(expected.count) keys, \(languages.joined(separator: ", ")).")
} else {
    failures.forEach { FileHandle.standardError.write(Data("\($0)\n".utf8)) }
    exit(1)
}
