//
//  PhoneticAlgorithms.swift
//  VoiceFilter_iOS
//
//  Thuật toán Soundex, Levenshtein và Double Metaphone viết thuần Swift
//  phục vụ so khớp âm thanh và nhận diện giọng nói thử thách Nói Chuẩn.
//

import Foundation

public struct Levenshtein {
    /// Tính khoảng cách Levenshtein giữa 2 chuỗi
    public static func distance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        let m = a.count
        let n = b.count

        if m == 0 { return n }
        if n == 0 { return m }

        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                let cost = (a[i - 1] == b[j - 1]) ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,       // deletion
                    matrix[i][j - 1] + 1,       // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }
        return matrix[m][n]
    }

    /// Tính tỉ lệ tương đồng từ 0.0 (hoàn toàn khác) đến 1.0 (giống nhau 100%)
    public static func similarityRatio(_ s1: String, _ s2: String) -> Double {
        let maxLen = max(s1.count, s2.count)
        if maxLen == 0 { return 1.0 }
        let dist = distance(s1, s2)
        return 1.0 - (Double(dist) / Double(maxLen))
    }
}

public struct Soundex {
    public static func encode(_ input: String) -> String {
        let clean = input.uppercased().filter { $0.isLetter }
        guard let first = clean.first else { return "" }

        func mapChar(_ c: Character) -> Character? {
            switch c {
            case "B", "F", "P", "V": return "1"
            case "C", "G", "J", "K", "Q", "S", "X", "Z": return "2"
            case "D", "T": return "3"
            case "L": return "4"
            case "M", "N": return "5"
            case "R": return "6"
            default: return nil
            }
        }

        var result = [first]
        var lastCode = mapChar(first)

        for c in clean.dropFirst() {
            if result.count == 4 { break }
            if let code = mapChar(c) {
                if code != lastCode {
                    result.append(code)
                    lastCode = code
                }
            } else if c != "H" && c != "W" {
                lastCode = nil
            }
        }

        while result.count < 4 {
            result.append("0")
        }
        return String(result)
    }
}

/// Thuật toán Double Metaphone thu gọn thuần Swift tối ưu cho tiếng Anh
public struct DoubleMetaphone {
    public struct Codes {
        public let primary: String
        public let secondary: String
    }

    public static func encode(_ input: String) -> Codes {
        let upper = input.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if upper.isEmpty { return Codes(primary: "", secondary: "") }

        var primary = ""
        var secondary = ""

        var chars = Array(upper)
        var length = chars.count
        var current = 0

        // Bỏ qua các ký tự không phải chữ
        chars = chars.filter { $0.isLetter }
        length = chars.count
        if length == 0 { return Codes(primary: "", secondary: "") }

        while current < length && primary.count < 4 {
            let ch = chars[current]
            switch ch {
            case "A", "E", "I", "O", "U", "Y":
                if current == 0 {
                    primary.append("A")
                    secondary.append("A")
                }
                current += 1
            case "B":
                primary.append("P")
                secondary.append("P")
                current += (current + 1 < length && chars[current + 1] == "B") ? 2 : 1
            case "C":
                // Xử lý CH, CK, C
                if current + 1 < length && chars[current + 1] == "H" {
                    primary.append("X")
                    secondary.append("K")
                    current += 2
                } else if current + 1 < length && (chars[current + 1] == "I" || chars[current + 1] == "E" || chars[current + 1] == "Y") {
                    primary.append("S")
                    secondary.append("S")
                    current += 2
                } else {
                    primary.append("K")
                    secondary.append("K")
                    current += (current + 1 < length && chars[current + 1] == "K") ? 2 : 1
                }
            case "D":
                if current + 1 < length && chars[current + 1] == "G" {
                    primary.append("J")
                    secondary.append("K")
                    current += 2
                } else {
                    primary.append("T")
                    secondary.append("T")
                    current += (current + 1 < length && chars[current + 1] == "D") ? 2 : 1
                }
            case "F":
                primary.append("F")
                secondary.append("F")
                current += (current + 1 < length && chars[current + 1] == "F") ? 2 : 1
            case "G":
                if current + 1 < length && (chars[current + 1] == "I" || chars[current + 1] == "E" || chars[current + 1] == "Y") {
                    primary.append("J")
                    secondary.append("K")
                    current += 2
                } else {
                    primary.append("K")
                    secondary.append("K")
                    current += (current + 1 < length && chars[current + 1] == "G") ? 2 : 1
                }
            case "H":
                if current + 1 < length && "AEIOUY".contains(chars[current + 1]) {
                    primary.append("H")
                    secondary.append("H")
                    current += 2
                } else {
                    current += 1
                }
            case "J":
                primary.append("J")
                secondary.append("A")
                current += (current + 1 < length && chars[current + 1] == "J") ? 2 : 1
            case "K":
                primary.append("K")
                secondary.append("K")
                current += (current + 1 < length && chars[current + 1] == "K") ? 2 : 1
            case "L":
                primary.append("L")
                secondary.append("L")
                current += (current + 1 < length && chars[current + 1] == "L") ? 2 : 1
            case "M":
                primary.append("M")
                secondary.append("M")
                current += (current + 1 < length && chars[current + 1] == "M") ? 2 : 1
            case "N":
                primary.append("N")
                secondary.append("N")
                current += (current + 1 < length && chars[current + 1] == "N") ? 2 : 1
            case "P":
                if current + 1 < length && chars[current + 1] == "H" {
                    primary.append("F")
                    secondary.append("F")
                    current += 2
                } else {
                    primary.append("P")
                    secondary.append("P")
                    current += (current + 1 < length && chars[current + 1] == "P") ? 2 : 1
                }
            case "Q":
                primary.append("K")
                secondary.append("K")
                current += (current + 1 < length && chars[current + 1] == "Q") ? 2 : 1
            case "R":
                primary.append("R")
                secondary.append("R")
                current += (current + 1 < length && chars[current + 1] == "R") ? 2 : 1
            case "S":
                if current + 1 < length && chars[current + 1] == "H" {
                    primary.append("X")
                    secondary.append("X")
                    current += 2
                } else {
                    primary.append("S")
                    secondary.append("S")
                    current += (current + 1 < length && chars[current + 1] == "S") ? 2 : 1
                }
            case "T":
                if current + 1 < length && chars[current + 1] == "H" {
                    primary.append("0")
                    secondary.append("T")
                    current += 2
                } else {
                    primary.append("T")
                    secondary.append("T")
                    current += (current + 1 < length && chars[current + 1] == "T") ? 2 : 1
                }
            case "V":
                primary.append("F")
                secondary.append("F")
                current += (current + 1 < length && chars[current + 1] == "V") ? 2 : 1
            case "W":
                if current + 1 < length && "AEIOUY".contains(chars[current + 1]) {
                    primary.append("A")
                    secondary.append("F")
                }
                current += 1
            case "X":
                primary.append("KS")
                secondary.append("KS")
                current += 1
            case "Z":
                primary.append("S")
                secondary.append("S")
                current += (current + 1 < length && chars[current + 1] == "Z") ? 2 : 1
            default:
                current += 1
            }
        }

        return Codes(
            primary: String(primary.prefix(4)),
            secondary: String(secondary.prefix(4))
        )
    }
}
