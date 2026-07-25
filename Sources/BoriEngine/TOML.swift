import Foundation

public enum TOMLError: Error, Equatable, CustomStringConvertible {
    case syntax(line: Int, message: String)

    public var description: String {
        switch self {
        case .syntax(let line, let message):
            return "line \(line): \(message)"
        }
    }
}

/// A deliberately small TOML reader — just the subset ~/.bori.toml uses:
/// comments, [tables], [[arrays of tables]], strings, integers, floats,
/// booleans, bare HH:MM times, and (possibly multiline) arrays.
public enum TOML {
    public static func parse(_ text: String) throws -> [String: Any] {
        var root: [String: Any] = [:]
        var currentPath: [String] = []
        let lines = text.components(separatedBy: .newlines)
        var i = 0
        while i < lines.count {
            let lineNumber = i + 1
            let line = stripComment(lines[i]).trimmingCharacters(in: .whitespaces)
            i += 1
            if line.isEmpty { continue }

            if line.hasPrefix("[[") {
                guard line.hasSuffix("]]"), line.count > 4 else {
                    throw TOMLError.syntax(line: lineNumber, message: "malformed [[table]] header")
                }
                let path = try keyPath(String(line.dropFirst(2).dropLast(2)), line: lineNumber)
                try appendTableArray(&root, path: path, line: lineNumber)
                currentPath = path
                continue
            }
            if line.hasPrefix("[") {
                guard line.hasSuffix("]"), line.count > 2 else {
                    throw TOMLError.syntax(line: lineNumber, message: "malformed [table] header")
                }
                let path = try keyPath(String(line.dropFirst().dropLast()), line: lineNumber)
                try ensureTable(&root, path: path, line: lineNumber)
                currentPath = path
                continue
            }

            guard let eq = topLevelEqualsIndex(line) else {
                throw TOMLError.syntax(line: lineNumber, message: "expected key = value")
            }
            let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else {
                throw TOMLError.syntax(line: lineNumber, message: "empty key")
            }
            var valueText = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            while bracketBalance(valueText) > 0 && i < lines.count {
                valueText += "\n" + stripComment(lines[i])
                i += 1
            }
            let value = try parseValue(valueText.trimmingCharacters(in: .whitespacesAndNewlines), line: lineNumber)
            try assign(&root, path: currentPath, key: key, value: value, line: lineNumber)
        }
        return root
    }

    // MARK: - Values

    private static func parseValue(_ text: String, line: Int) throws -> Any {
        if text.hasPrefix("\"") {
            return try parseBasicString(text, line: line)
        }
        if text.hasPrefix("'") {
            guard text.count >= 2, text.hasSuffix("'") else {
                throw TOMLError.syntax(line: line, message: "unterminated literal string")
            }
            return String(text.dropFirst().dropLast())
        }
        if text.hasPrefix("[") {
            guard text.hasSuffix("]") else {
                throw TOMLError.syntax(line: line, message: "unterminated array")
            }
            let inner = String(text.dropFirst().dropLast())
            var items: [Any] = []
            for piece in splitTopLevel(inner) {
                let trimmed = piece.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue } // trailing comma
                items.append(try parseValue(trimmed, line: line))
            }
            return items
        }
        if text == "true" { return true }
        if text == "false" { return false }
        if let n = Int(text) { return n }
        if let d = Double(text) { return d }
        if isBareTime(text) { return text } // TOML local time, e.g. 09:00 — kept as a string
        throw TOMLError.syntax(line: line, message: "unrecognised value: \(text)")
    }

    private static func parseBasicString(_ text: String, line: Int) throws -> String {
        var out = ""
        var chars = text.dropFirst().makeIterator()
        var closed = false
        while let c = chars.next() {
            if closed {
                throw TOMLError.syntax(line: line, message: "text after closing quote")
            }
            switch c {
            case "\"": closed = true
            case "\\":
                guard let e = chars.next() else {
                    throw TOMLError.syntax(line: line, message: "dangling escape")
                }
                switch e {
                case "n": out.append("\n")
                case "t": out.append("\t")
                case "r": out.append("\r")
                case "\"": out.append("\"")
                case "\\": out.append("\\")
                default:
                    throw TOMLError.syntax(line: line, message: "unsupported escape \\\(e)")
                }
            default: out.append(c)
            }
        }
        guard closed else {
            throw TOMLError.syntax(line: line, message: "unterminated string")
        }
        return out
    }

    private static func isBareTime(_ text: String) -> Bool {
        let parts = text.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]),
              (0...23).contains(h), (0...59).contains(m) else { return false }
        return true
    }

    // MARK: - Structure

    private static func keyPath(_ text: String, line: Int) throws -> [String] {
        let parts = text.split(separator: ".").map { $0.trimmingCharacters(in: .whitespaces) }
        guard !parts.isEmpty, !parts.contains(where: \.isEmpty) else {
            throw TOMLError.syntax(line: line, message: "malformed table name")
        }
        return parts
    }

    private static func assign(_ dict: inout [String: Any], path: [String], key: String, value: Any, line: Int) throws {
        guard let head = path.first else {
            dict[key] = value
            return
        }
        let rest = Array(path.dropFirst())
        if var arr = dict[head] as? [[String: Any]] {
            guard !arr.isEmpty else {
                throw TOMLError.syntax(line: line, message: "assignment into empty table array \(head)")
            }
            var last = arr.removeLast()
            try assign(&last, path: rest, key: key, value: value, line: line)
            arr.append(last)
            dict[head] = arr
        } else {
            var child = dict[head] as? [String: Any] ?? [:]
            try assign(&child, path: rest, key: key, value: value, line: line)
            dict[head] = child
        }
    }

    private static func ensureTable(_ dict: inout [String: Any], path: [String], line: Int) throws {
        guard let head = path.first else { return }
        let rest = Array(path.dropFirst())
        if var arr = dict[head] as? [[String: Any]] {
            guard !arr.isEmpty else {
                throw TOMLError.syntax(line: line, message: "table inside empty array \(head)")
            }
            var last = arr.removeLast()
            try ensureTable(&last, path: rest, line: line)
            arr.append(last)
            dict[head] = arr
        } else {
            var child = dict[head] as? [String: Any] ?? [:]
            try ensureTable(&child, path: rest, line: line)
            dict[head] = child
        }
    }

    private static func appendTableArray(_ dict: inout [String: Any], path: [String], line: Int) throws {
        guard let head = path.first else { return }
        if path.count == 1 {
            var arr = dict[head] as? [[String: Any]] ?? []
            if dict[head] != nil && !(dict[head] is [[String: Any]]) {
                throw TOMLError.syntax(line: line, message: "\(head) is not an array of tables")
            }
            arr.append([:])
            dict[head] = arr
            return
        }
        let rest = Array(path.dropFirst())
        if var arr = dict[head] as? [[String: Any]] {
            guard !arr.isEmpty else {
                throw TOMLError.syntax(line: line, message: "array of tables inside empty array \(head)")
            }
            var last = arr.removeLast()
            try appendTableArray(&last, path: rest, line: line)
            arr.append(last)
            dict[head] = arr
        } else {
            var child = dict[head] as? [String: Any] ?? [:]
            try appendTableArray(&child, path: rest, line: line)
            dict[head] = child
        }
    }

    // MARK: - Scanning helpers

    private static func stripComment(_ line: String) -> String {
        var inBasic = false, inLiteral = false, escaped = false
        var out = ""
        for c in line {
            if inBasic {
                if escaped { escaped = false }
                else if c == "\\" { escaped = true }
                else if c == "\"" { inBasic = false }
            } else if inLiteral {
                if c == "'" { inLiteral = false }
            } else {
                if c == "\"" { inBasic = true }
                else if c == "'" { inLiteral = true }
                else if c == "#" { return out }
            }
            out.append(c)
        }
        return out
    }

    private static func topLevelEqualsIndex(_ line: String) -> String.Index? {
        var inBasic = false, inLiteral = false, escaped = false
        for idx in line.indices {
            let c = line[idx]
            if inBasic {
                if escaped { escaped = false }
                else if c == "\\" { escaped = true }
                else if c == "\"" { inBasic = false }
            } else if inLiteral {
                if c == "'" { inLiteral = false }
            } else {
                if c == "\"" { inBasic = true }
                else if c == "'" { inLiteral = true }
                else if c == "=" { return idx }
            }
        }
        return nil
    }

    private static func bracketBalance(_ text: String) -> Int {
        var inBasic = false, inLiteral = false, escaped = false
        var depth = 0
        for c in text {
            if inBasic {
                if escaped { escaped = false }
                else if c == "\\" { escaped = true }
                else if c == "\"" { inBasic = false }
            } else if inLiteral {
                if c == "'" { inLiteral = false }
            } else {
                if c == "\"" { inBasic = true }
                else if c == "'" { inLiteral = true }
                else if c == "[" { depth += 1 }
                else if c == "]" { depth -= 1 }
            }
        }
        return depth
    }

    private static func splitTopLevel(_ text: String) -> [String] {
        var pieces: [String] = []
        var current = ""
        var inBasic = false, inLiteral = false, escaped = false
        var depth = 0
        for c in text {
            if inBasic {
                if escaped { escaped = false }
                else if c == "\\" { escaped = true }
                else if c == "\"" { inBasic = false }
                current.append(c)
                continue
            }
            if inLiteral {
                if c == "'" { inLiteral = false }
                current.append(c)
                continue
            }
            switch c {
            case "\"": inBasic = true; current.append(c)
            case "'": inLiteral = true; current.append(c)
            case "[": depth += 1; current.append(c)
            case "]": depth -= 1; current.append(c)
            case "," where depth == 0:
                pieces.append(current)
                current = ""
            default: current.append(c)
            }
        }
        pieces.append(current)
        return pieces
    }
}
