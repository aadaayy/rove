import Foundation

/// What a receipt scan suggests. Every field is shown to the person to check
/// before anything is saved.
struct ReceiptDraft: Hashable {
    var merchant: String?
    var date: Date?
    var subtotalMinor: Int64?
    var taxMinor: Int64?
    var tipMinor: Int64?
    var totalMinor: Int64?
    var currency: String?

    var isEmpty: Bool {
        merchant == nil && date == nil && subtotalMinor == nil && taxMinor == nil && tipMinor == nil && totalMinor == nil
    }
}

/// Reads the text lines found on a receipt (by the phone's on-device text
/// recognition) and picks out the merchant, date, subtotal, tax, tip and
/// total. No item-by-item lines for now.
enum ReceiptParser {
    static func parse(lines rawLines: [String], defaultCurrency: String, calendar: Calendar = .current) -> ReceiptDraft {
        let lines = rawLines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        var draft = ReceiptDraft()
        draft.currency = currency(in: lines)
        let digits = Currencies.digits(draft.currency ?? defaultCurrency)

        var totals: [Int64] = []
        var allAmounts: [Int64] = []
        for (index, line) in lines.enumerated() {
            let lower = line.lowercased()
            var amounts = self.amounts(in: line, digits: digits)
            // Some receipts put the label and the amount on separate lines.
            if amounts.isEmpty, isLabelOnly(lower), index + 1 < lines.count {
                let next = lines[index + 1]
                if next.rangeOfCharacter(from: .letters) == nil {
                    amounts = self.amounts(in: next, digits: digits)
                }
            }
            allAmounts += amounts
            guard let value = amounts.last else { continue }
            if hasWord(lower, ["subtotal", "sub total", "sub-total"]) {
                draft.subtotalMinor = value
            } else if hasWord(lower, ["tip", "gratuity", "propina"]) && !contains(lower, ["suggested", "tip guide", "%:"]) {
                draft.tipMinor = value
            } else if hasWord(lower, ["tax", "sales tax", "vat", "iva", "hst", "gst"]) && !hasWord(lower, ["total"]) {
                draft.taxMinor = (draft.taxMinor ?? 0) + value
            } else if hasWord(lower, ["total", "amount due", "balance due", "amount paid", "importe"]) && !hasWord(lower, ["items", "savings"]) {
                totals.append(value)
            }
        }

        if let largestTotal = totals.max() {
            draft.totalMinor = largestTotal
        } else if let subtotal = draft.subtotalMinor {
            draft.totalMinor = subtotal + (draft.taxMinor ?? 0) + (draft.tipMinor ?? 0)
        } else {
            draft.totalMinor = allAmounts.max()
        }
        // A total printed before the tip was added: add the tip back on.
        if let total = draft.totalMinor, let tip = draft.tipMinor, let subtotal = draft.subtotalMinor,
           total == subtotal + (draft.taxMinor ?? 0) {
            draft.totalMinor = total + tip
        }

        draft.merchant = merchant(in: lines)
        draft.date = lines.lazy.compactMap { date(in: $0, calendar: calendar) }.first
        return draft
    }

    // MARK: - Pieces

    private static func contains(_ text: String, _ words: [String]) -> Bool {
        words.contains { text.contains($0) }
    }

    /// Whole words only, so "tip" doesn't match "multiple" or "tax" "taxi".
    private static func hasWord(_ text: String, _ words: [String]) -> Bool {
        words.contains { word in
            let escaped = NSRegularExpression.escapedPattern(for: word)
            return text.range(of: "\\b\(escaped)\\b", options: .regularExpression) != nil
        }
    }

    private static func isLabelOnly(_ lower: String) -> Bool {
        hasWord(lower, ["total", "subtotal", "tax", "tip", "gratuity", "amount due", "balance due"])
    }

    private static let amountPattern = try! NSRegularExpression(pattern: #"(?<![\d.,])-?\$?\s?(\d{1,3}(?:,\d{3})+|\d+)([.,]\d{2})(?![\d])"#)
    private static let wholePattern = try! NSRegularExpression(pattern: #"(?<![\d.,])(\d{1,3}(?:,\d{3})+|\d+)(?![\d.,])"#)

    /// Money amounts on a line, like "12.34" or "$1,234.56". For currencies
    /// without cents, whole numbers count.
    static func amounts(in line: String, digits: Int = 2) -> [Int64] {
        let range = NSRange(line.startIndex..., in: line)
        if digits == 0 {
            return wholePattern.matches(in: line, range: range).compactMap { match in
                guard let r = Range(match.range(at: 1), in: line) else { return nil }
                return Int64(line[r].replacingOccurrences(of: ",", with: ""))
            }
        }
        return amountPattern.matches(in: line, range: range).compactMap { match in
            guard let wholeRange = Range(match.range(at: 1), in: line),
                  let fractionRange = Range(match.range(at: 2), in: line) else { return nil }
            let whole = line[wholeRange].replacingOccurrences(of: ",", with: "")
            let fraction = line[fractionRange].dropFirst()
            guard let w = Int64(whole), let f = Int64(fraction) else { return nil }
            return w * 100 + f
        }
    }

    private static func currency(in lines: [String]) -> String? {
        let text = lines.joined(separator: " ")
        let upper = text.uppercased()
        for code in Currencies.codes where code != "USD" {
            if upper.range(of: "\\b\(code)\\b", options: .regularExpression) != nil { return code }
        }
        if text.contains("€") { return "EUR" }
        if text.contains("£") { return "GBP" }
        if text.contains("¥") { return "JPY" }
        if upper.range(of: "\\bUSD\\b", options: .regularExpression) != nil || text.contains("$") { return "USD" }
        return nil
    }

    private static let skipWords = ["receipt", "welcome", "thank", "order", "table", "server", "guest", "check", "invoice", "copy", "store #", "tel", "phone", "www", ".com", "visa", "mastercard", "amex"]

    /// The first line that reads like a business name.
    private static func merchant(in lines: [String]) -> String? {
        for line in lines.prefix(6) {
            let lower = line.lowercased()
            let letters = line.filter(\.isLetter).count
            let numbers = line.filter(\.isNumber).count
            guard letters >= 3, numbers <= letters / 3, !contains(lower, skipWords) else { continue }
            guard amounts(in: line).isEmpty else { continue }
            return line.split(separator: " ").map { word -> String in
                let w = String(word)
                guard w == w.uppercased(), w.count > 2 else { return w }
                return String(w.prefix(1)) + w.dropFirst().lowercased()
            }.joined(separator: " ")
        }
        return nil
    }

    private static let numericDate = try! NSRegularExpression(pattern: #"\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})\b"#)
    private static let isoDate = try! NSRegularExpression(pattern: #"\b(\d{4})-(\d{1,2})-(\d{1,2})\b"#)
    private static let wordDate = try! NSRegularExpression(pattern: #"\b(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?\s+(\d{1,2}),?\s+(\d{4})\b"#, options: .caseInsensitive)

    static func date(in line: String, calendar: Calendar = .current) -> Date? {
        let range = NSRange(line.startIndex..., in: line)
        func number(_ match: NSTextCheckingResult, _ i: Int) -> Int? {
            Range(match.range(at: i), in: line).flatMap { Int(line[$0]) }
        }
        func make(_ y: Int, _ m: Int, _ d: Int) -> Date? {
            guard (1...12).contains(m), (1...31).contains(d), (2000...2100).contains(y) else { return nil }
            return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))
        }
        if let match = isoDate.firstMatch(in: line, range: range),
           let y = number(match, 1), let m = number(match, 2), let d = number(match, 3) {
            return make(y, m, d)
        }
        if let match = numericDate.firstMatch(in: line, range: range),
           let a = number(match, 1), let b = number(match, 2), var y = number(match, 3) {
            if y < 100 { y += 2000 }
            // US receipts first: month/day. Fall back to day/month when the
            // first number can't be a month.
            return make(y, a, b) ?? make(y, b, a)
        }
        if let match = wordDate.firstMatch(in: line, range: range),
           let monthRange = Range(match.range(at: 1), in: line),
           let d = number(match, 2), let y = number(match, 3) {
            let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
            let key = String(line[monthRange].lowercased().prefix(3))
            if let index = months.firstIndex(of: key) { return make(y, index + 1, d) }
        }
        return nil
    }
}
